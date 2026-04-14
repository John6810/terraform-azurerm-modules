###############################################################
# MODULE: ActionGroup - Outputs
###############################################################

output "id" {
  description = "The ID of the Action Group"
  value       = azurerm_monitor_action_group.this.id
}

output "name" {
  description = "The name of the Action Group"
  value       = azurerm_monitor_action_group.this.name
}

output "resource" {
  description = "The complete Action Group resource object"
  value       = azurerm_monitor_action_group.this
  sensitive   = true
}
