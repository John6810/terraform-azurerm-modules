###############################################################
# MODULE: Grafana - Outputs
###############################################################

output "resource_group_name" {
  description = "Grafana resource group name"
  value       = azurerm_resource_group.this.name
}

output "grafana_id" {
  description = "Azure Managed Grafana instance ID"
  value       = azurerm_dashboard_grafana.this.id
}

output "grafana_name" {
  description = "Azure Managed Grafana instance name"
  value       = azurerm_dashboard_grafana.this.name
}

output "grafana_endpoint" {
  description = "Grafana endpoint URL"
  value       = azurerm_dashboard_grafana.this.endpoint
}

output "grafana_resource" {
  description = "The complete Grafana resource object"
  value       = azurerm_dashboard_grafana.this
}

output "identity_id" {
  description = "Grafana managed identity ID"
  value       = azurerm_user_assigned_identity.this.id
}

output "identity_principal_id" {
  description = "Grafana managed identity principal ID"
  value       = azurerm_user_assigned_identity.this.principal_id
}

output "identity_client_id" {
  description = "Grafana managed identity client ID"
  value       = azurerm_user_assigned_identity.this.client_id
}
