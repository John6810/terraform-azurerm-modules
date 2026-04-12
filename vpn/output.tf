# ═══════════════════════════════════════════════════════════════════════════════
# VPN GATEWAY OUTPUTS
# ═══════════════════════════════════════════════════════════════════════════════

output "resource" {
  description = "The complete Virtual Network Gateway resource object"
  value       = azurerm_virtual_network_gateway.vpn_gateway
}

output "vpn_gateway_id" {
  description = "ID of the VPN Gateway"
  value       = azurerm_virtual_network_gateway.vpn_gateway.id
}

output "vpn_gateway_name" {
  description = "Name of the VPN Gateway"
  value       = azurerm_virtual_network_gateway.vpn_gateway.name
}

output "vpn_gateway_public_ip" {
  description = "Public IP address of the VPN Gateway"
  value       = azurerm_public_ip.vpn_gateway_pip.ip_address
}

output "vpn_gateway_public_ip_id" {
  description = "ID of the primary Public IP"
  value       = azurerm_public_ip.vpn_gateway_pip.id
}

output "vpn_gateway_public_ip_secondary" {
  description = "Secondary public IP address (if active-active is enabled)"
  value       = var.active_active ? azurerm_public_ip.vpn_gateway_pip_secondary[0].ip_address : null
}

output "vpn_gateway_public_ip_secondary_id" {
  description = "ID of the secondary Public IP (if active-active is enabled)"
  value       = var.active_active ? azurerm_public_ip.vpn_gateway_pip_secondary[0].id : null
}

output "vpn_gateway_bgp_settings" {
  description = "BGP settings of the VPN Gateway"
  value       = var.enable_bgp ? azurerm_virtual_network_gateway.vpn_gateway.bgp_settings : null
}

output "local_network_gateway_ids" {
  description = "Map of local network gateway IDs"
  value       = { for k, v in azurerm_local_network_gateway.local_gateways : k => v.id }
}

output "connection_ids" {
  description = "Map of VPN connection IDs"
  value       = { for k, v in azurerm_virtual_network_gateway_connection.connections : k => v.id }
}
