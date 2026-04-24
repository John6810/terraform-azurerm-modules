###############################################################
# MODULE: AvdApplicationGroup - Outputs
###############################################################

output "id" {
  description = "Application group resource ID"
  value       = azurerm_virtual_desktop_application_group.this.id
}

output "name" {
  description = "Application group name"
  value       = azurerm_virtual_desktop_application_group.this.name
}

output "workspace_association_id" {
  description = "ID of the workspace association (null if workspace_id not set)"
  value       = try(azurerm_virtual_desktop_workspace_application_group_association.this[0].id, null)
}
