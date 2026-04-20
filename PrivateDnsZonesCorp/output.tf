###############################################################
# MODULE: PrivateDnsZonesCorp - Outputs
###############################################################

output "resource_group_name" {
  description = "Name of the resource group hosting the zones"
  value       = azurerm_resource_group.this.name
}

output "resource_group_id" {
  description = "ID of the resource group hosting the zones"
  value       = azurerm_resource_group.this.id
}

output "zone_ids" {
  description = "Map of zone name => zone resource ID"
  value = {
    for name, zone in azurerm_private_dns_zone.this : name => zone.id
  }
}

output "zone_names" {
  description = "Set of zone names created"
  value       = [for zone in azurerm_private_dns_zone.this : zone.name]
}
