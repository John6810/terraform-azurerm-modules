###############################################################
# MODULE: LogAnalyticsAlerts - Outputs
###############################################################

output "alert_ids" {
  description = "Map of alert key → resource ID."
  value       = { for k, r in azurerm_monitor_scheduled_query_rules_alert_v2.this : k => r.id }
}

output "alert_names" {
  description = "Map of alert key → full resource name."
  value       = { for k, r in azurerm_monitor_scheduled_query_rules_alert_v2.this : k => r.name }
}
