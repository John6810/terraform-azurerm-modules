###############################################################
# MODULE: ExpressRouteCircuit - Main
# Description: ExpressRoute circuit with optional Azure Private
#              Peering. Service key is exposed as an output so it
#              can be shared with the provider (DE-CIX, Equinix…).
###############################################################

resource "time_static" "time" {}

locals {
  computed_name = "er-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.workload}"
  name          = var.name != null ? var.name : local.computed_name
}

resource "azurerm_express_route_circuit" "this" {
  name                  = local.name
  location              = var.location
  resource_group_name   = var.resource_group_name
  service_provider_name = var.service_provider_name
  peering_location      = var.peering_location
  bandwidth_in_mbps     = var.bandwidth_in_mbps

  sku {
    tier   = var.sku_tier
    family = var.sku_family
  }

  allow_classic_operations = var.allow_classic_operations

  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}

resource "azurerm_express_route_circuit_peering" "private" {
  count = var.private_peering != null ? 1 : 0

  peering_type                  = "AzurePrivatePeering"
  express_route_circuit_name    = azurerm_express_route_circuit.this.name
  resource_group_name           = var.resource_group_name
  peer_asn                      = var.private_peering.peer_asn
  primary_peer_address_prefix   = var.private_peering.primary_peer_address_prefix
  secondary_peer_address_prefix = var.private_peering.secondary_peer_address_prefix
  vlan_id                       = var.private_peering.vlan_id
  shared_key                    = var.private_peering.shared_key
  ipv4_enabled                  = var.private_peering.ipv4_enabled
}

resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_express_route_circuit.this.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}
