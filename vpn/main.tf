# ═══════════════════════════════════════════════════════════════════════════════
# NAMING CONVENTION
# Convention: vpng-{subscription_acronym}-{environment}-{region_code}-{workload}
# Example:    vpng-con-prod-gwc-001
# ═══════════════════════════════════════════════════════════════════════════════

locals {
  computed_name = "vpng-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.workload}"
  name          = var.name != null ? var.name : local.computed_name
}

# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC IP(s) FOR VPN GATEWAY
# ═══════════════════════════════════════════════════════════════════════════════

resource "azurerm_public_ip" "vpn_gateway_pip" {
  name                = "${local.name}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = endswith(var.sku, "AZ") ? ["1", "2", "3"] : null

  tags = var.tags
}

resource "azurerm_public_ip" "vpn_gateway_pip_secondary" {
  count = var.active_active ? 1 : 0

  name                = "${local.name}-pip-secondary"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = endswith(var.sku, "AZ") ? ["1", "2", "3"] : null

  tags = var.tags
}

# ═══════════════════════════════════════════════════════════════════════════════
# VPN GATEWAY
# ═══════════════════════════════════════════════════════════════════════════════

resource "azurerm_virtual_network_gateway" "vpn_gateway" {
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name

  type          = var.type
  vpn_type      = var.type == "Vpn" ? var.vpn_type : null
  generation    = var.type == "Vpn" ? var.generation : null
  sku           = var.sku
  active_active = var.active_active
  enable_bgp    = var.enable_bgp

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway_pip.id
    private_ip_address_allocation = var.private_ip_address_allocation
    subnet_id                     = var.subnet_id
  }

  dynamic "ip_configuration" {
    for_each = var.active_active ? [1] : []

    content {
      name                          = "vnetGatewayConfig-secondary"
      public_ip_address_id          = azurerm_public_ip.vpn_gateway_pip_secondary[0].id
      private_ip_address_allocation = var.private_ip_address_allocation
      subnet_id                     = var.subnet_id
    }
  }

  dynamic "bgp_settings" {
    for_each = var.enable_bgp && var.bgp_settings != null ? [var.bgp_settings] : []

    content {
      asn         = bgp_settings.value.asn
      peer_weight = bgp_settings.value.peer_weight
    }
  }

  dynamic "vpn_client_configuration" {
    for_each = var.vpn_client_configuration != null ? [var.vpn_client_configuration] : []

    content {
      address_space        = vpn_client_configuration.value.address_space
      vpn_client_protocols = vpn_client_configuration.value.vpn_client_protocols
      aad_tenant           = vpn_client_configuration.value.aad_tenant
      aad_audience         = vpn_client_configuration.value.aad_audience
      aad_issuer           = vpn_client_configuration.value.aad_issuer

      dynamic "root_certificate" {
        for_each = vpn_client_configuration.value.root_certificate

        content {
          name             = root_certificate.value.name
          public_cert_data = root_certificate.value.public_cert_data
        }
      }

      dynamic "revoked_certificate" {
        for_each = vpn_client_configuration.value.revoked_certificate

        content {
          name       = revoked_certificate.value.name
          thumbprint = revoked_certificate.value.thumbprint
        }
      }
    }
  }

  tags = var.tags
}

# ═══════════════════════════════════════════════════════════════════════════════
# LOCAL NETWORK GATEWAYS AND CONNECTIONS
# ═══════════════════════════════════════════════════════════════════════════════

resource "azurerm_local_network_gateway" "local_gateways" {
  for_each = var.local_network_gateways

  name                = "${local.name}-lng-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name
  gateway_address     = each.value.gateway_address
  address_space       = each.value.address_space

  dynamic "bgp_settings" {
    for_each = each.value.bgp_settings != null ? [each.value.bgp_settings] : []

    content {
      asn                 = bgp_settings.value.asn
      bgp_peering_address = bgp_settings.value.bgp_peering_address
      peer_weight         = bgp_settings.value.peer_weight
    }
  }

  tags = var.tags
}

resource "azurerm_virtual_network_gateway_connection" "connections" {
  for_each = var.local_network_gateways

  name                = "${local.name}-conn-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn_gateway.id
  local_network_gateway_id   = azurerm_local_network_gateway.local_gateways[each.key].id

  shared_key                         = each.value.shared_key
  connection_mode                    = each.value.connection_mode
  connection_protocol                = each.value.connection_protocol
  enable_bgp                         = each.value.enable_bgp
  dpd_timeout_seconds                = each.value.dpd_timeout_seconds
  use_policy_based_traffic_selectors = each.value.use_policy_based_traffic_selectors

  tags = var.tags
}

# ═══════════════════════════════════════════════════════════════════════════════
# RESOURCE: Management Lock
# ═══════════════════════════════════════════════════════════════════════════════

resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_virtual_network_gateway.vpn_gateway.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}
