###############################################################
# MODULE: Ampls - Outputs
###############################################################

output "ampls_id" {
  description = "The ID of the Azure Monitor Private Link Scope"
  value       = azurerm_monitor_private_link_scope.this.id
}

output "ampls_resource" {
  description = "The complete AMPLS resource object"
  value       = azurerm_monitor_private_link_scope.this
}

output "private_endpoint_id" {
  description = "The ID of the AMPLS private endpoint"
  value       = azurerm_private_endpoint.this.id
}

output "private_ip_address" {
  description = "The private IP address of the AMPLS private endpoint"
  value       = try(azurerm_private_endpoint.this.private_service_connection[0].private_ip_address, null)
}
