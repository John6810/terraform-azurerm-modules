###############################################################
# MODULE: SubnetWithNsg - Outputs
###############################################################

output "subnet_ids" {
  description = "Map of subnet name => subnet ID"
  value       = { for k, s in azapi_resource.subnet : k => s.id }
}

output "resources" {
  description = "Map of subnet name => complete azapi_resource object"
  value       = azapi_resource.subnet
}
