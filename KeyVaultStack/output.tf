###############################################################
# MODULE: KeyVaultStack - Outputs
###############################################################

###############################################################
# Resource Group
###############################################################
output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.this.name
}

output "resource_group_id" {
  description = "The ID of the resource group"
  value       = azurerm_resource_group.this.id
}

###############################################################
# Key Vault
###############################################################
output "key_vault_id" {
  description = "The Key Vault resource ID"
  value       = azurerm_key_vault.this.id
}

output "key_vault_name" {
  description = "The Key Vault name"
  value       = azurerm_key_vault.this.name
}

output "key_vault_uri" {
  description = "The Key Vault URI (e.g., https://kv-name.vault.azure.net/)"
  value       = azurerm_key_vault.this.vault_uri
}

output "key_vault_tenant_id" {
  description = "The Key Vault tenant ID"
  value       = azurerm_key_vault.this.tenant_id
}

output "key_vault_resource" {
  description = "The complete Key Vault resource object"
  value       = azurerm_key_vault.this
}

###############################################################
# Private Endpoint
###############################################################
output "private_endpoint_id" {
  description = "The Private Endpoint resource ID"
  value       = azurerm_private_endpoint.this.id
}

output "private_endpoint_name" {
  description = "The Private Endpoint name"
  value       = azurerm_private_endpoint.this.name
}

output "private_endpoint_ip" {
  description = "The private IP address of the Private Endpoint"
  value       = try(azurerm_private_endpoint.this.private_service_connection[0].private_ip_address, null)
}

output "private_endpoint_connection_status" {
  description = "The connection status of the Private Endpoint"
  value       = try(data.azurerm_private_endpoint_connection.this.private_service_connection[0].status, "Unknown")
}
