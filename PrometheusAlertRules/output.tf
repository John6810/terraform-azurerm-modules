###############################################################
# MODULE: PrometheusAlertRules - Outputs
###############################################################

output "ids" {
  description = "Map of rule group key to resource ID"
  value       = { for k, v in azurerm_monitor_alert_prometheus_rule_group.this : k => v.id }
}

output "names" {
  description = "Map of rule group key to resource name"
  value       = { for k, v in azurerm_monitor_alert_prometheus_rule_group.this : k => v.name }
}
