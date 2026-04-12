###############################################################
# MODULE: ContainerRegistry - Outputs
###############################################################

output "id" {
  description = "Container Registry ID"
  value       = azurerm_container_registry.this.id
}

output "name" {
  description = "Container Registry name"
  value       = azurerm_container_registry.this.name
}

output "login_server" {
  description = "Login server URL (e.g. crapiprodgwc001.azurecr.io)"
  value       = azurerm_container_registry.this.login_server
}

output "resource" {
  description = "The complete Container Registry resource object"
  value       = azurerm_container_registry.this
}
