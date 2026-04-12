output "id" {
  description = "The ID of the Managed HSM"
  value       = azurerm_key_vault_managed_hardware_security_module.this.id
}

output "name" {
  description = "The name of the Managed HSM"
  value       = azurerm_key_vault_managed_hardware_security_module.this.name
}

output "hsm_uri" {
  description = "The URI of the Managed HSM"
  value       = azurerm_key_vault_managed_hardware_security_module.this.hsm_uri
}

output "identity_id" {
  description = "The ID of the HSM User Assigned Identity"
  value       = azurerm_user_assigned_identity.hsm.id
}

output "identity_principal_id" {
  description = "The Principal ID of the HSM User Assigned Identity"
  value       = azurerm_user_assigned_identity.hsm.principal_id
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

###############################################################
# Private Endpoint
###############################################################
output "private_endpoint_id" {
  description = "The ID of the Private Endpoint"
  value       = var.private_endpoint_subnet_id != null ? azurerm_private_endpoint.this[0].id : null
}

output "private_endpoint_ip" {
  description = "The private IP address of the Private Endpoint"
  value       = var.private_endpoint_subnet_id != null ? azurerm_private_endpoint.this[0].private_service_connection[0].private_ip_address : null
}

###############################################################
# Full Resource Object
###############################################################
output "resource" {
  description = "The complete HSM resource object"
  value       = azurerm_key_vault_managed_hardware_security_module.this
}
