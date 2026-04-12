###############################################################
# ALZ Management Module
###############################################################
output "resource" {
  description = "The complete ALZ Management module output object"
  value       = module.alz_management
}

###############################################################
# Log Analytics Workspace
###############################################################
output "law_id" {
  description = "The ID of the Log Analytics Workspace"
  value       = module.alz_management.log_analytics_workspace.id
}

output "law_name" {
  description = "The name of the Log Analytics Workspace"
  value       = module.alz_management.log_analytics_workspace.name
}

output "law_workspace_id" {
  description = "The Workspace ID (GUID) of the Log Analytics Workspace"
  value       = module.alz_management.log_analytics_workspace.workspace_id
}

###############################################################
# Automation Account
###############################################################
output "automation_account_id" {
  description = "The ID of the Automation Account"
  value       = module.alz_management.automation_account.id
}

output "automation_account_name" {
  description = "The name of the Automation Account"
  value       = module.alz_management.automation_account.name
}

###############################################################
# Identities
###############################################################
output "law_identity_id" {
  description = "The ID of the LAW User Assigned Identity"
  value       = azurerm_user_assigned_identity.law.id
}

output "ama_identity_id" {
  description = "The ID of the AMA User Assigned Identity"
  value       = module.alz_management.user_assigned_identity_ids.ama.id
}

###############################################################
# Resource Group (when created inline)
###############################################################
output "resource_group_name" {
  description = "The name of the resource group"
  value       = local.resource_group_name
}

output "resource_group_id" {
  description = "The ID of the resource group (only when created inline)"
  value       = var.create_resource_group ? azurerm_resource_group.this[0].id : null
}

