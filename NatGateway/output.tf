output "id" {
  description = "The ID of the NAT Gateway"
  value       = azapi_resource.nat_gateway.id
}

output "name" {
  description = "The name of the NAT Gateway"
  value       = azapi_resource.nat_gateway.name
}

output "public_ip_address" {
  description = "The public IP address of the NAT Gateway"
  value       = azapi_resource.public_ip.output.properties.ipAddress
}

output "public_ip_id" {
  description = "The ID of the public IP"
  value       = azapi_resource.public_ip.id
}
