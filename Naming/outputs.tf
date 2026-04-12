###############################################################
# MODULE: Naming - Outputs
###############################################################

output "azure_naming" {
  description = "The full Azure naming module object (access any resource type via .resource_type.name)"
  value       = module.azure_naming
}

output "all_names" {
  description = "Combined map of all resource names (Azure module + custom)"
  value       = local.all_names
}

output "custom_names" {
  description = "Custom resource names (sanitized)"
  value       = local.sanitize_name
}

output "storage_names" {
  description = "Sanitized storage account names (lowercase, alphanumeric only, max 24 chars)"
  value       = local.sanitize_storage_name
}

output "built_names" {
  description = "Pre-built resource names with all name_suffixes applied"
  value       = local.build_name
}
