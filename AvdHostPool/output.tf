###############################################################
# MODULE: AvdHostPool - Outputs
###############################################################

output "id" {
  description = "Host pool resource ID"
  value       = azurerm_virtual_desktop_host_pool.this.id
}

output "name" {
  description = "Host pool name"
  value       = azurerm_virtual_desktop_host_pool.this.name
}

output "registration_token" {
  description = "Registration token for session host DSC extension (null if create_registration_info=false)"
  value       = try(azurerm_virtual_desktop_host_pool_registration_info.this[0].token, null)
  sensitive   = true
}

output "resource" {
  description = "Full host pool resource object"
  value       = azurerm_virtual_desktop_host_pool.this
}
