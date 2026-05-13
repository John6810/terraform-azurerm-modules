###############################################################
# MODULE: ContainerInsightsCollector - Outputs
###############################################################

output "dcr_id" {
  description = "Resource ID of the Container Insights Data Collection Rule."
  value       = azurerm_monitor_data_collection_rule.ci.id
}

output "dcr_name" {
  description = "Name of the Container Insights Data Collection Rule."
  value       = azurerm_monitor_data_collection_rule.ci.name
}

output "dcra_id" {
  description = "Resource ID of the DCR association on the AKS cluster."
  value       = azurerm_monitor_data_collection_rule_association.ci.id
}
