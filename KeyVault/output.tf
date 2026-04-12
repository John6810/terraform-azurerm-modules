###############################################################
# MODULE: KeyVault - Outputs
###############################################################

output "id" {
  description = "The Key Vault resource ID"
  value       = azurerm_key_vault.this.id
}

output "name" {
  description = "The Key Vault name"
  value       = azurerm_key_vault.this.name
}

output "uri" {
  description = "The Key Vault URI (e.g., https://kv-name.vault.azure.net/)"
  value       = azurerm_key_vault.this.vault_uri
}

output "tenant_id" {
  description = "The Key Vault tenant ID"
  value       = azurerm_key_vault.this.tenant_id
}

output "resource" {
  description = "The complete Key Vault resource object"
  value       = azurerm_key_vault.this
}
