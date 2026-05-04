output "id" {
  description = "The ID of the NAT Gateway"
  value       = azapi_resource.nat_gateway.id
}

output "name" {
  description = "The name of the NAT Gateway"
  value       = azapi_resource.nat_gateway.name
}

output "public_ip_address" {
  description = "The public IP address of the base NAT Gateway PIP"
  value       = azapi_resource.public_ip.output.properties.ipAddress
}

output "public_ip_id" {
  description = "The ID of the base public IP"
  value       = azapi_resource.public_ip.id
}

output "additional_public_ip_addresses" {
  description = "Map of additional public IP key => address (empty when no additional PIPs are configured)."
  value       = { for k, pip in azapi_resource.additional_public_ip : k => pip.output.properties.ipAddress }
}

output "additional_public_ip_ids" {
  description = "Map of additional public IP key => resource ID."
  value       = { for k, pip in azapi_resource.additional_public_ip : k => pip.id }
}

output "all_public_ip_addresses" {
  description = "Flat list of all public IP addresses attached to the NAT Gateway (base + additional)."
  value = concat(
    [azapi_resource.public_ip.output.properties.ipAddress],
    [for pip in azapi_resource.additional_public_ip : pip.output.properties.ipAddress],
  )
}
