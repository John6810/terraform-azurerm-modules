###############################################################
# MODULE: NetworkStack - Main
#
# Composes a regional spoke (or hub) network footprint:
#   RG (optional) → Network Watcher (optional) → vnet → Route Table
#   → NSGs → Subnets (azapi single-PUT for ALZ NSG-required policy)
#
# Suitable for AVD, AKS, App Service, generic VMs, Bastion, NetApp,
# dedicated PE subnets, or any combination via the subnets map.
###############################################################

resource "time_static" "time" {}

###############################################################
# Naming
###############################################################
locals {
  prefix = "${var.subscription_acronym}-${var.environment}-${var.region_code}"

  rg_name_default       = "rg-${local.prefix}-${var.resource_group_workload}"
  vnet_name_default     = "vnet-${local.prefix}-${var.workload}"
  rt_name_default       = "rt-${local.prefix}-${var.workload}"
  nw_name_default       = "nw-${local.prefix}-${var.resource_group_workload}"
  nsg_name_template_key = "nsg-${local.prefix}" # appended with -${subnet_key}

  rg_name   = var.create_resource_group ? local.rg_name_default : var.resource_group_name
  vnet_name = coalesce(var.vnet_name, local.vnet_name_default)
  rt_name   = coalesce(var.route_table_name, local.rt_name_default)
  nw_name   = coalesce(var.network_watcher_name, local.nw_name_default)

  effective_rg_name = var.create_resource_group ? azurerm_resource_group.this[0].name : var.resource_group_name
  effective_rg_id   = var.create_resource_group ? azurerm_resource_group.this[0].id : data.azurerm_resource_group.existing[0].id

  # Subnets that need an NSG created by this module
  subnets_with_nsg = { for k, v in var.subnets : k => v if v.create_nsg }

  # Subnet name resolution per entry
  subnet_names = {
    for k, v in var.subnets : k => coalesce(v.name, "snet-${local.prefix}-${k}")
  }

  # Tags merged with CreatedOn for traceability
  effective_tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}

###############################################################
# DATA: existing RG when not creating one
###############################################################
data "azurerm_resource_group" "existing" {
  count = var.create_resource_group ? 0 : 1
  name  = var.resource_group_name
}

###############################################################
# RESOURCE: Resource Group
###############################################################
resource "azurerm_resource_group" "this" {
  count = var.create_resource_group ? 1 : 0

  name     = local.rg_name
  location = var.location
  tags     = local.effective_tags
}

###############################################################
# RESOURCE: Network Watcher
# Note: Azure also auto-creates one named NetworkWatcher_<region>
# in AzureNetworkWatcherRG. Set create_network_watcher=false if
# you intend to consume that one or already have your own.
###############################################################
resource "azurerm_network_watcher" "this" {
  count = var.create_network_watcher ? 1 : 0

  name                = local.nw_name
  location            = var.location
  resource_group_name = local.effective_rg_name
  tags                = local.effective_tags
}

###############################################################
# RESOURCE: Virtual Network
###############################################################
resource "azurerm_virtual_network" "this" {
  name                = local.vnet_name
  location            = var.location
  resource_group_name = local.effective_rg_name

  address_space           = var.vnet_address_space
  dns_servers             = var.dns_servers
  flow_timeout_in_minutes = var.flow_timeout_in_minutes

  dynamic "ddos_protection_plan" {
    for_each = var.ddos_protection_plan_id != null ? [1] : []
    content {
      id     = var.ddos_protection_plan_id
      enable = true
    }
  }

  dynamic "encryption" {
    for_each = var.encryption_enforcement != null ? [1] : []
    content {
      enforcement = var.encryption_enforcement
    }
  }

  tags = local.effective_tags
}

###############################################################
# RESOURCE: Route Table
###############################################################
resource "azurerm_route_table" "this" {
  count = var.create_route_table ? 1 : 0

  name                          = local.rt_name
  location                      = var.location
  resource_group_name           = local.effective_rg_name
  bgp_route_propagation_enabled = var.bgp_route_propagation_enabled

  tags = local.effective_tags
}

###############################################################
# RESOURCE: Default Route (0.0.0.0/0) — only if next hop IP set
###############################################################
resource "azurerm_route" "default" {
  count = var.create_route_table && var.default_route_next_hop_ip != null ? 1 : 0

  name                = "default-udr"
  resource_group_name = local.effective_rg_name
  route_table_name    = azurerm_route_table.this[0].name
  address_prefix      = "0.0.0.0/0"
  next_hop_type       = var.default_route_next_hop_type
  next_hop_in_ip_address = contains(["VirtualAppliance"], var.default_route_next_hop_type) ? var.default_route_next_hop_ip : null
}

###############################################################
# RESOURCE: Extra Routes (optional)
###############################################################
resource "azurerm_route" "extra" {
  for_each = var.create_route_table ? var.extra_routes : {}

  name                   = each.key
  resource_group_name    = local.effective_rg_name
  route_table_name       = azurerm_route_table.this[0].name
  address_prefix         = each.value.address_prefix
  next_hop_type          = each.value.next_hop_type
  next_hop_in_ip_address = each.value.next_hop_in_ip_address
}

###############################################################
# RESOURCE: NSGs (one per subnet that opts in)
###############################################################
resource "azurerm_network_security_group" "this" {
  for_each = local.subnets_with_nsg

  name                = "${local.nsg_name_template_key}-${each.key}"
  location            = var.location
  resource_group_name = local.effective_rg_name

  dynamic "security_rule" {
    for_each = each.value.nsg_rules
    content {
      name                                       = security_rule.value.name
      priority                                   = security_rule.value.priority
      direction                                  = security_rule.value.direction
      access                                     = security_rule.value.access
      protocol                                   = security_rule.value.protocol
      source_port_range                          = security_rule.value.source_port_range
      destination_port_range                     = security_rule.value.destination_port_range
      source_address_prefix                      = security_rule.value.source_address_prefix
      destination_address_prefix                 = security_rule.value.destination_address_prefix
      source_port_ranges                         = security_rule.value.source_port_ranges
      destination_port_ranges                    = security_rule.value.destination_port_ranges
      source_address_prefixes                    = security_rule.value.source_address_prefixes
      destination_address_prefixes               = security_rule.value.destination_address_prefixes
      source_application_security_group_ids      = security_rule.value.source_application_security_group_ids
      destination_application_security_group_ids = security_rule.value.destination_application_security_group_ids
      description                                = security_rule.value.description
    }
  }

  tags = local.effective_tags
}

###############################################################
# RESOURCE: Subnets (azapi single-PUT)
#
# Using azapi instead of azurerm_subnet so the NSG (and RT)
# associations land in the same PUT as the subnet creation —
# required to satisfy 'Subnets must have a NSG' deny policy.
###############################################################
resource "azapi_resource" "subnet" {
  for_each = var.subnets

  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  name      = local.subnet_names[each.key]
  parent_id = azurerm_virtual_network.this.id

  body = {
    properties = merge(
      {
        addressPrefix                 = each.value.cidr
        defaultOutboundAccess         = each.value.default_outbound_access_enabled
        privateEndpointNetworkPolicies = each.value.private_endpoint_network_policies
      },
      each.value.create_nsg ? {
        networkSecurityGroup = {
          id = azurerm_network_security_group.this[each.key].id
        }
      } : {},
      var.create_route_table && each.value.attach_route_table ? {
        routeTable = {
          id = azurerm_route_table.this[0].id
        }
      } : {},
      length(each.value.service_endpoints) > 0 ? {
        serviceEndpoints = [for s in each.value.service_endpoints : { service = s }]
      } : {},
      each.value.delegation != null ? {
        delegations = [{
          name = each.value.delegation.name
          properties = {
            serviceName = each.value.delegation.service_name
          }
        }]
      } : {},
    )
  }

  response_export_values = ["id", "name"]

  lifecycle {
    # ALZ DINE policies may inject privateEndpointNetworkPolicies side-effects;
    # keep authoritative on the explicit set above without fighting policy.
    ignore_changes = [
      body.properties.privateLinkServiceNetworkPolicies,
    ]
  }
}

###############################################################
# HUB PEERING (optional spoke->hub)
#
# When var.hub_peering is set, creates the spoke->hub peering inline so
# the network deployment is self-contained. The reverse hub->spoke
# peering must be declared on the hub side (connectivity sub) — Azure
# requires both sides for 'Connected' state.
###############################################################
resource "azurerm_virtual_network_peering" "hub" {
  count = var.hub_peering != null ? 1 : 0

  name                         = var.hub_peering.name
  resource_group_name          = local.effective_rg_name
  virtual_network_name         = azurerm_virtual_network.this.name
  remote_virtual_network_id    = var.hub_peering.remote_virtual_network_id
  allow_forwarded_traffic      = var.hub_peering.allow_forwarded_traffic
  allow_gateway_transit        = var.hub_peering.allow_gateway_transit
  use_remote_gateways          = var.hub_peering.use_remote_gateways
  allow_virtual_network_access = true
}
