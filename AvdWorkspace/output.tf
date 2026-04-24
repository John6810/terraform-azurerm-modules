###############################################################
# MODULE: AvdWorkspace - Outputs
###############################################################

output "id" {
  description = "Workspace resource ID"
  value       = azurerm_virtual_desktop_workspace.this.id
}

output "name" {
  description = "Workspace name"
  value       = azurerm_virtual_desktop_workspace.this.name
}
