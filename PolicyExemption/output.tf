###############################################################
# MODULE: PolicyExemption - Outputs
###############################################################

output "ids" {
  description = "Map of exemption key to resource ID."
  value       = { for k, v in azurerm_resource_group_policy_exemption.this : k => v.id }
}

output "names" {
  description = "Map of exemption key to resource name."
  value       = { for k, v in azurerm_resource_group_policy_exemption.this : k => v.name }
}
