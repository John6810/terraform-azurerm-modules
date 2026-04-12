###############################################################
# MODULE: DdosProtection - Outputs
###############################################################

output "id" {
  description = "The ID of the DDoS Protection Plan"
  value       = azurerm_network_ddos_protection_plan.this.id
}

output "name" {
  description = "The name of the DDoS Protection Plan"
  value       = azurerm_network_ddos_protection_plan.this.name
}

output "resource" {
  description = "The complete DDoS Protection Plan resource object"
  value       = azurerm_network_ddos_protection_plan.this
}
