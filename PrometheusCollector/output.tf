###############################################################
# MODULE: PrometheusCollector - Outputs
###############################################################

output "dcr_id" {
  description = "The ID of the Data Collection Rule"
  value       = azurerm_monitor_data_collection_rule.prometheus.id
}

output "dcr_name" {
  description = "The name of the Data Collection Rule"
  value       = azurerm_monitor_data_collection_rule.prometheus.name
}

output "resource" {
  description = "The complete Data Collection Rule resource object"
  value       = azurerm_monitor_data_collection_rule.prometheus
}
