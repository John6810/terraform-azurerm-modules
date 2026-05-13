###############################################################
# MODULE: RoleAssignment - Outputs
###############################################################

output "id" {
  description = "Resource ID of the role assignment."
  value       = azurerm_role_assignment.this.id
}

output "name" {
  description = "Name (GUID) of the role assignment."
  value       = azurerm_role_assignment.this.name
}
