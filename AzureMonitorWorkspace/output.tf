###############################################################
# MODULE: AzureMonitorWorkspace - Outputs
###############################################################

output "id" {
  description = "The ID of the Azure Monitor Workspace"
  value       = azurerm_monitor_workspace.this.id
}

output "name" {
  description = "The name of the Azure Monitor Workspace"
  value       = azurerm_monitor_workspace.this.name
}

output "query_endpoint" {
  description = "The query endpoint for the Azure Monitor Workspace"
  value       = azurerm_monitor_workspace.this.query_endpoint
}

output "default_data_collection_endpoint_id" {
  description = "The default Data Collection Endpoint ID"
  value       = azurerm_monitor_workspace.this.default_data_collection_endpoint_id
}

output "default_data_collection_rule_id" {
  description = "The default Data Collection Rule ID"
  value       = azurerm_monitor_workspace.this.default_data_collection_rule_id
}

output "resource" {
  description = "The complete Azure Monitor Workspace resource object"
  value       = azurerm_monitor_workspace.this
}

output "private_endpoint_id" {
  description = "The ID of the Private Endpoint (null if no PE)"
  value       = var.subnet_id != null ? azurerm_private_endpoint.this[0].id : null
}

output "private_endpoint_ip" {
  description = "The private IP address of the Private Endpoint"
  value       = var.subnet_id != null ? azurerm_private_endpoint.this[0].private_service_connection[0].private_ip_address : null
}
