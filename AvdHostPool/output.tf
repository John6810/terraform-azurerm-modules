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

output "resource" {
  description = "Full host pool resource object"
  value       = azurerm_virtual_desktop_host_pool.this
}
