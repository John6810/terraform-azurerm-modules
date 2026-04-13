###############################################################
# MODULE: DiagnosticSettings - Main
# Description: Creates diagnostic settings for Azure resources
###############################################################

resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = var.diagnostic_settings

  name                           = each.value.name
  target_resource_id             = each.value.target_resource_id
  log_analytics_workspace_id     = each.value.log_analytics_workspace_id
  storage_account_id             = each.value.storage_account_id
  eventhub_authorization_rule_id = each.value.event_hub_authorization_rule_id
  eventhub_name                  = each.value.event_hub_name
  partner_solution_id            = each.value.marketplace_partner_resource_id

  dynamic "enabled_log" {
    for_each = each.value.logs
    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = each.value.metrics
    content {
      category = enabled_metric.value
    }
  }
}
