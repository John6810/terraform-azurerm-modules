###############################################################
# MODULE: StorageAccount - Outputs
###############################################################

output "id" {
  description = "Storage Account ID"
  value       = azurerm_storage_account.this.id
}

output "name" {
  description = "Storage Account name"
  value       = azurerm_storage_account.this.name
}

output "primary_blob_endpoint" {
  description = "Primary blob endpoint URL"
  value       = azurerm_storage_account.this.primary_blob_endpoint
}

output "primary_access_key" {
  description = "Primary access key"
  value       = azurerm_storage_account.this.primary_access_key
  sensitive   = true
}

output "primary_file_endpoint" {
  description = "Primary Azure Files endpoint URL"
  value       = azurerm_storage_account.this.primary_file_endpoint
}

output "file_shares" {
  description = "Map of file share key => { id, name, url }"
  value = {
    for k, v in azurerm_storage_share.this : k => {
      id   = v.id
      name = v.name
      url  = v.url
    }
  }
}

output "resource" {
  description = "The complete Storage Account resource object"
  value       = azurerm_storage_account.this
  sensitive   = true
}
