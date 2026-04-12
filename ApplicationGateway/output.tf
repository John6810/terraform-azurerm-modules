###############################################################
# MODULE: ApplicationGateway - Outputs
###############################################################

output "id" {
  description = "Application Gateway ID"
  value       = azurerm_application_gateway.this.id
}

output "name" {
  description = "Application Gateway name"
  value       = azurerm_application_gateway.this.name
}

output "waf_policy_id" {
  description = "WAF Policy ID"
  value       = azurerm_web_application_firewall_policy.this.id
}

output "public_ip_address" {
  description = "Public IP address (if created)"
  value       = var.create_public_ip ? azurerm_public_ip.this[0].ip_address : null
}

output "private_ip_address" {
  description = "Private IP address of the frontend"
  value       = [for fe in azurerm_application_gateway.this.frontend_ip_configuration : fe.private_ip_address if fe.name == "frontend-private"][0]
}

output "resource" {
  description = "The complete Application Gateway resource object"
  value       = azurerm_application_gateway.this
}
