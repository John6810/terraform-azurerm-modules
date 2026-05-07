###############################################################
# MODULE: PolicyAssignment - Outputs
###############################################################

output "assignment_ids" {
  description = "Map of assignment name => resource ID (across all scopes)."
  value = merge(
    { for k, v in azurerm_resource_group_policy_assignment.this : k => v.id },
    { for k, v in azurerm_subscription_policy_assignment.this : k => v.id },
    { for k, v in azurerm_management_group_policy_assignment.this : k => v.id },
  )
}

output "identity_principal_ids" {
  description = "Map of assignment name => system-assigned identity principal ID (only for assignments with identity_type set)."
  value = merge(
    { for k, v in azurerm_resource_group_policy_assignment.this : k => try(v.identity[0].principal_id, null) if length(v.identity) > 0 },
    { for k, v in azurerm_subscription_policy_assignment.this : k => try(v.identity[0].principal_id, null) if length(v.identity) > 0 },
    { for k, v in azurerm_management_group_policy_assignment.this : k => try(v.identity[0].principal_id, null) if length(v.identity) > 0 },
  )
}
