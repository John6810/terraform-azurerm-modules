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

output "vault_uri" {
  description = "The Key Vault URI (e.g., https://kv-name.vault.azure.net/). Mirrors azurerm_key_vault.vault_uri — preferred over the legacy `uri` output."
  value       = azurerm_key_vault.this.vault_uri
}

output "uri" {
  description = "DEPRECATED — use `vault_uri` instead. Kept for backwards compatibility with existing callers; will be removed in a future major version."
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
