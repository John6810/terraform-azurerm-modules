output "resource" {
  description = "Full ALZ architecture module output object"
  value       = module.alz_architecture
}

output "management_group_ids" {
  description = "Map of management group IDs"
  value       = module.alz_architecture.management_group_resource_ids
}

output "policy_assignment_identity_ids" {
  description = "Map of policy assignment identity principal IDs"
  value       = module.alz_architecture.policy_assignment_identity_ids
}
