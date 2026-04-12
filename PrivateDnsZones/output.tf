output "resource_group_name" {
  description = "The name of the DNS resource group"
  value       = azurerm_resource_group.this.name
}

output "resource_group_id" {
  description = "The ID of the DNS resource group"
  value       = azurerm_resource_group.this.id
}

output "private_dns_zone_resource_ids" {
  description = "Map of private DNS zone names to their resource IDs"
  value       = module.private_dns_zones.private_dns_zone_resource_ids
}
