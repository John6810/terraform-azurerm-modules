###############################################################
# MODULE: ResourceGroup - Outputs
###############################################################

output "id" {
  description = "The ID of the resource group"
  value       = azurerm_resource_group.this.id
}

output "name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.this.name
}

output "location" {
  description = "The location of the resource group"
  value       = azurerm_resource_group.this.location
}

output "tags" {
  description = "The tags applied to the resource group"
  value       = azurerm_resource_group.this.tags
}

output "resource" {
  description = "The complete resource group object"
  value       = azurerm_resource_group.this
}
