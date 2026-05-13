###############################################################
# MODULE: SecurityCenterWorkspace - Outputs
###############################################################

output "id" {
  description = "Resource ID of the workspaceSettings (always .../workspaceSettings/default)."
  value       = azurerm_security_center_workspace.this.id
}

output "scope" {
  description = "Subscription scope this setting applies to."
  value       = azurerm_security_center_workspace.this.scope
}

output "workspace_id" {
  description = "Log Analytics Workspace resource ID receiving Defender for Cloud data."
  value       = azurerm_security_center_workspace.this.workspace_id
}
