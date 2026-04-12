###############################################################
# Full Resource
###############################################################
output "resource" {
  description = "The full resource group object."
  value       = azurerm_resource_group.this
}

###############################################################
# Resource Group
###############################################################
output "resource_group_name" {
  description = "Cluster resource group name."
  value       = azurerm_resource_group.this.name
}

output "resource_group_id" {
  description = "Cluster resource group ID."
  value       = azurerm_resource_group.this.id
}

###############################################################
# Internal Load Balancer
###############################################################
output "ilb_id" {
  description = "Internal Load Balancer ID."
  value       = azurerm_lb.trust.id
}

output "ilb_frontend_ip" {
  description = "Internal Load Balancer frontend IP."
  value       = azurerm_lb.trust.frontend_ip_configuration[0].private_ip_address
}

output "ilb_backend_pool_id" {
  description = "Internal Load Balancer backend pool ID."
  value       = azurerm_lb_backend_address_pool.trust.id
}

###############################################################
# Disk Encryption
###############################################################
output "disk_encryption_set_id" {
  description = "Disk Encryption Set ID (null if no CMK)."
  value       = length(azurerm_disk_encryption_set.this) > 0 ? azurerm_disk_encryption_set.this[0].id : null
}

output "key_vault_id" {
  description = "Key Vault ID for disk encryption (null if disabled)."
  value       = length(azurerm_key_vault.this) > 0 ? azurerm_key_vault.this[0].id : null
}

output "des_identity_principal_id" {
  description = "DES managed identity principal ID."
  value       = length(azurerm_user_assigned_identity.des) > 0 ? azurerm_user_assigned_identity.des[0].principal_id : null
}

###############################################################
# VM-Series
###############################################################
output "vm_ids" {
  description = "Map of key => VM ID."
  value       = { for k, v in azurerm_linux_virtual_machine.this : k => v.id }
}

output "vm_names" {
  description = "Map of key => VM name."
  value       = { for k, v in azurerm_linux_virtual_machine.this : k => v.name }
}

output "mgmt_private_ips" {
  description = "Map of key => management private IP."
  value       = { for k, v in azurerm_network_interface.mgmt : k => v.private_ip_address }
}

###############################################################
# Application Insights
###############################################################
output "appinsights_instrumentation_keys" {
  description = "Map of key => APPI instrumentation key (for PAN-OS config)."
  value       = { for k, v in azurerm_application_insights.this : k => v.instrumentation_key }
  sensitive   = true
}

output "appinsights_connection_strings" {
  description = "Map of key => APPI connection string."
  value       = { for k, v in azurerm_application_insights.this : k => v.connection_string }
  sensitive   = true
}
