# ═══════════════════════════════════════════════════════════════════════════════
# VIRTUAL WAN OUTPUTS
# ═══════════════════════════════════════════════════════════════════════════════

output "resource" {
  description = "The complete Virtual WAN resource object"
  value       = azurerm_virtual_wan.vwan
}

output "virtual_wan_id" {
  description = "ID of the Virtual WAN"
  value       = azurerm_virtual_wan.vwan.id
}

output "virtual_wan_name" {
  description = "Name of the Virtual WAN"
  value       = azurerm_virtual_wan.vwan.name
}

# ═══════════════════════════════════════════════════════════════════════════════
# VIRTUAL HUB OUTPUTS
# ═══════════════════════════════════════════════════════════════════════════════

output "virtual_hub_ids" {
  description = "Map of Virtual Hub IDs"
  value       = { for k, v in azurerm_virtual_hub.hubs : k => v.id }
}

output "virtual_hub_names" {
  description = "Map of Virtual Hub names"
  value       = { for k, v in azurerm_virtual_hub.hubs : k => v.name }
}

output "virtual_hub_default_route_table_ids" {
  description = "Map of Virtual Hub default route table IDs"
  value       = { for k, v in azurerm_virtual_hub.hubs : k => v.default_route_table_id }
}

# ═══════════════════════════════════════════════════════════════════════════════
# VIRTUAL HUB CONNECTION OUTPUTS
# ═══════════════════════════════════════════════════════════════════════════════

output "virtual_hub_connection_ids" {
  description = "Map of Virtual Hub Connection IDs"
  value       = { for k, v in azurerm_virtual_hub_connection.connections : k => v.id }
}

# ═══════════════════════════════════════════════════════════════════════════════
# VPN GATEWAY OUTPUTS
# ═══════════════════════════════════════════════════════════════════════════════

output "vpn_gateway_ids" {
  description = "Map of VPN Gateway IDs"
  value       = { for k, v in azurerm_vpn_gateway.hub_vpn_gateways : k => v.id }
}

output "vpn_gateway_bgp_settings" {
  description = "Map of VPN Gateway BGP settings"
  value = {
    for k, v in azurerm_vpn_gateway.hub_vpn_gateways : k => {
      asn               = v.bgp_settings[0].asn
      peer_weight       = v.bgp_settings[0].peer_weight
      instance_0_bgp_ip = tolist(v.bgp_settings[0].instance_0_bgp_peering_address[0].default_ips)[0]
      instance_1_bgp_ip = tolist(v.bgp_settings[0].instance_1_bgp_peering_address[0].default_ips)[0]
    }
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXPRESS ROUTE GATEWAY OUTPUTS
# ═══════════════════════════════════════════════════════════════════════════════

output "express_route_gateway_ids" {
  description = "Map of ExpressRoute Gateway IDs"
  value       = { for k, v in azurerm_express_route_gateway.hub_er_gateways : k => v.id }
}

output "express_route_connection_ids" {
  description = "Map of ExpressRoute Connection IDs (circuit peering ↔ hub ER GW)"
  value       = { for k, v in azurerm_express_route_connection.hub_er_connections : k => v.id }
}

# ═══════════════════════════════════════════════════════════════════════════════
# FIREWALL OUTPUTS
# ═══════════════════════════════════════════════════════════════════════════════

output "firewall_ids" {
  description = "Map of Azure Firewall IDs"
  value       = { for k, v in azurerm_firewall.hub_firewalls : k => v.id }
}

output "firewall_private_ips" {
  description = "Map of Azure Firewall private IP addresses"
  value       = { for k, v in azurerm_firewall.hub_firewalls : k => v.virtual_hub[0].private_ip_address }
}

# ═══════════════════════════════════════════════════════════════════════════════
# P2S GATEWAY OUTPUTS
# ═══════════════════════════════════════════════════════════════════════════════

output "vpn_server_configuration_ids" {
  description = "Map of VPN Server Configuration IDs"
  value       = { for k, v in azurerm_vpn_server_configuration.configs : k => v.id }
}

output "p2s_gateway_ids" {
  description = "Map of Point-to-Site VPN Gateway IDs"
  value       = { for k, v in azurerm_point_to_site_vpn_gateway.p2s_gateways : k => v.id }
}

# ═══════════════════════════════════════════════════════════════════════════════
# BGP CONNECTION OUTPUTS
# ═══════════════════════════════════════════════════════════════════════════════

output "bgp_connection_ids" {
  description = "Map of Virtual Hub BGP Connection IDs"
  value       = { for k, v in azurerm_virtual_hub_bgp_connection.bgp : k => v.id }
}

# ═══════════════════════════════════════════════════════════════════════════════
# VPN SITE OUTPUTS
# ═══════════════════════════════════════════════════════════════════════════════

output "vpn_site_ids" {
  description = "Map of VPN Site IDs"
  value       = { for k, v in azurerm_vpn_site.sites : k => v.id }
}

# ═══════════════════════════════════════════════════════════════════════════════
# VPN CONNECTION OUTPUTS
# ═══════════════════════════════════════════════════════════════════════════════

output "vpn_connection_ids" {
  description = "Map of VPN Connection IDs"
  value       = { for k, v in azurerm_vpn_gateway_connection.connections : k => v.id }
}

output "vpn_gateway_public_ips" {
  description = "Map of VPN Gateway public IP addresses (instance 0 and 1) — needed for on-premises CPE configuration"
  value = {
    for k, v in azurerm_vpn_gateway.hub_vpn_gateways : k => {
      instance_0_ip = tolist(v.bgp_settings[0].instance_0_bgp_peering_address[0].tunnel_ips)[1]
      instance_1_ip = tolist(v.bgp_settings[0].instance_1_bgp_peering_address[0].tunnel_ips)[1]
    }
  }
}
