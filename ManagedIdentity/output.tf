###############################################################
# MODULE: ManagedIdentity - Outputs
###############################################################

output "id" {
  description = "Managed identity ID"
  value       = azurerm_user_assigned_identity.this.id
}

output "name" {
  description = "Managed identity name"
  value       = azurerm_user_assigned_identity.this.name
}

output "principal_id" {
  description = "Identity principal ID (object ID)"
  value       = azurerm_user_assigned_identity.this.principal_id
}

output "client_id" {
  description = "Identity client ID (application ID)"
  value       = azurerm_user_assigned_identity.this.client_id
}

output "tenant_id" {
  description = "Tenant ID"
  value       = azurerm_user_assigned_identity.this.tenant_id
}

output "resource" {
  description = "The complete User Assigned Identity resource object"
  value       = azurerm_user_assigned_identity.this
}
