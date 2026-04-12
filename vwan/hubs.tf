# ═══════════════════════════════════════════════════════════════════════════════
# VIRTUAL HUBS
# ═══════════════════════════════════════════════════════════════════════════════

resource "azurerm_virtual_hub" "hubs" {
  for_each = var.virtual_hubs

  name                = "${var.name}-hub-${each.key}"
  resource_group_name = var.resource_group_name
  location            = coalesce(each.value.location, var.location)
  virtual_wan_id      = azurerm_virtual_wan.vwan.id
  address_prefix      = each.value.address_prefix
  sku                 = each.value.sku

  tags = var.tags
}

resource "azurerm_virtual_hub_route_table" "default" {
  for_each = {
    for k, v in var.virtual_hubs : k => v
    if length(v.routes) > 0
  }

  name           = "defaultRouteTable"
  virtual_hub_id = azurerm_virtual_hub.hubs[each.key].id

  dynamic "route" {
    for_each = each.value.routes

    content {
      name              = "route-${route.key}"
      destinations_type = "CIDR"
      destinations      = route.value.address_prefixes
      next_hop_type     = "ResourceId"
      next_hop          = route.value.next_hop_ip_address
    }
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# VIRTUAL HUB VNET CONNECTIONS
# ═══════════════════════════════════════════════════════════════════════════════

resource "azurerm_virtual_hub_connection" "connections" {
  for_each = var.virtual_hub_connections

  name                      = "${var.name}-conn-${each.key}"
  virtual_hub_id            = azurerm_virtual_hub.hubs[each.value.virtual_hub_key].id
  remote_virtual_network_id = each.value.remote_virtual_network_id
  internet_security_enabled = each.value.internet_security_enabled
}
