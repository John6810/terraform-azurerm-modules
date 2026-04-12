###############################################################
# MODULE: NetworkWatcher - Outputs
###############################################################

output "id" {
  description = "The ID of the Network Watcher"
  value       = azurerm_network_watcher.this.id
}

output "name" {
  description = "The name of the Network Watcher"
  value       = azurerm_network_watcher.this.name
}

output "resource" {
  description = "The complete Network Watcher resource object"
  value       = azurerm_network_watcher.this
}

###############################################################
# Resource Group outputs (when created inline)
###############################################################
output "resource_group_name" {
  description = "The name of the resource group"
  value       = local.resource_group_name
}

output "resource_group_id" {
  description = "The ID of the resource group (only when created inline)"
  value       = var.create_resource_group ? azurerm_resource_group.this[0].id : null
}
