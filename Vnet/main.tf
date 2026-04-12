###############################################################
# MODULE: Vnet - Main
# Description: Azure Virtual Network with optional inline subnets
###############################################################

resource "time_static" "time" {}

###############################################################
# Naming Convention
# Convention: vnet-{subscription_acronym}-{environment}-{region_code}-{workload}
# Example:    vnet-con-prod-gwc-hub
###############################################################
locals {
  computed_name = "vnet-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.workload}"
  name          = var.name != null ? var.name : local.computed_name
}

###############################################################
# RESOURCE: Virtual Network
###############################################################
resource "azurerm_virtual_network" "this" {
  name                = local.name
  address_space       = var.address_space
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_servers         = var.dns_servers

  dynamic "ddos_protection_plan" {
    for_each = var.enable_ddos_protection && var.ddos_protection_plan_id != null ? [var.ddos_protection_plan_id] : []
    content {
      enable = var.enable_ddos_protection
      id     = ddos_protection_plan.value
    }
  }

  dynamic "ip_address_pool" {
    for_each = var.ip_address_pool != null ? [var.ip_address_pool] : []
    content {
      id                     = ip_address_pool.value.id
      number_of_ip_addresses = ip_address_pool.value.number_of_ip_addresses
    }
  }

  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}

###############################################################
# RESOURCE: Management Lock
###############################################################
resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_virtual_network.this.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}

###############################################################
# RESOURCE: Inline Subnets (optional)
###############################################################
resource "azurerm_subnet" "this" {
  for_each = { for s in var.subnets : s.name => s }

  name                              = each.value.name
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = each.value.address_prefixes
  service_endpoints                 = each.value.service_endpoints
  default_outbound_access_enabled   = each.value.default_outbound_access_enabled
  private_endpoint_network_policies = each.value.private_endpoint_network_policies

  dynamic "ip_address_pool" {
    for_each = each.value.ip_address_pool != null ? [each.value.ip_address_pool] : []
    content {
      id                     = ip_address_pool.value.id
      number_of_ip_addresses = ip_address_pool.value.number_of_ip_addresses
    }
  }

  dynamic "delegation" {
    for_each = each.value.delegations
    content {
      name = delegation.value.name
      service_delegation {
        name    = delegation.value.service_delegation.name
        actions = delegation.value.service_delegation.actions
      }
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = {
    for s in var.subnets : s.name => s
    if s.nsg_id != null
  }

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = each.value.nsg_id
}

resource "azurerm_subnet_route_table_association" "this" {
  for_each = {
    for s in var.subnets : s.name => s
    if s.route_table_id != null
  }

  subnet_id      = azurerm_subnet.this[each.key].id
  route_table_id = each.value.route_table_id
}

resource "azurerm_subnet_nat_gateway_association" "this" {
  for_each = {
    for s in var.subnets : s.name => s
    if s.nat_gateway_id != null
  }

  subnet_id      = azurerm_subnet.this[each.key].id
  nat_gateway_id = each.value.nat_gateway_id
}
