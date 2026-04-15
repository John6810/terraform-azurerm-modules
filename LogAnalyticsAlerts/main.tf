###############################################################
# MODULE: LogAnalyticsAlerts - Main
# Description: Generic KQL-based Azure Monitor alerts on a LAW.
###############################################################

locals {
  name_prefix = "alert-${var.subscription_acronym}-${var.environment}-${var.region_code}"
}

###############################################################
# Custom tables (*_CL) — created before alerts so KQL references
# resolve at create time. Data-plane ingestion (AMPLS/PE) is NOT
# required for ARM table creation.
###############################################################
resource "azapi_resource" "custom_table" {
  for_each = var.custom_tables

  type      = "Microsoft.OperationalInsights/workspaces/tables@2022-10-01"
  parent_id = var.law_id
  name      = "${each.key}_CL"

  body = {
    properties = {
      plan               = each.value.plan
      retentionInDays    = each.value.retention_days
      totalRetentionInDays = each.value.total_retention_days
      schema = {
        name = "${each.key}_CL"
        columns = [
          for col_name, col_type in each.value.columns : {
            name = col_name
            type = col_type
          }
        ]
      }
    }
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "this" {
  for_each = var.alerts

  # Ensure custom tables exist before alerts are validated by Azure
  depends_on = [azapi_resource.custom_table]

  name                = "${local.name_prefix}-${each.key}"
  resource_group_name = var.resource_group_name
  location            = var.location

  display_name = coalesce(each.value.display_name, each.key)
  description  = each.value.description
  severity     = each.value.severity
  enabled      = each.value.enabled

  evaluation_frequency = each.value.evaluation_frequency
  window_duration      = each.value.window_duration
  scopes               = [var.law_id]

  criteria {
    query                   = each.value.kql
    time_aggregation_method = each.value.time_aggregation_method
    metric_measure_column   = each.value.metric_measure_column
    threshold               = each.value.threshold
    operator                = each.value.operator

    failing_periods {
      number_of_evaluation_periods             = each.value.failing_periods.number_of_evaluation_periods
      minimum_failing_periods_to_trigger_alert = each.value.failing_periods.minimum_failing_periods_to_trigger_alert
    }
  }

  action {
    action_groups     = coalesce(each.value.action_group_ids, var.action_group_ids)
    custom_properties = each.value.custom_properties
  }

  auto_mitigation_enabled = each.value.auto_mitigation_enabled

  tags = var.tags
}
