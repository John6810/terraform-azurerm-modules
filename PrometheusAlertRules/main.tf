###############################################################
# MODULE: PrometheusAlertRules - Main
# Description: Prometheus alert rule groups for AKS clusters,
#              backed by Azure Monitor Workspace.
#              Supports multiple groups (Azure limit: 20 rules/group).
###############################################################

resource "time_static" "time" {}

###############################################################
# Naming Convention + Action group merge
###############################################################
locals {
  prefix = "${var.subscription_acronym}-${var.environment}-${var.region_code}"

  # action_group_id (mandatory single) + action_group_ids (optional extras)
  # → distinct list capped at 5 (Azure hard limit per alert rule).
  action_group_ids = distinct(concat(
    [var.action_group_id],
    var.action_group_ids,
  ))
}

###############################################################
# RESOURCE: Prometheus Alert Rule Groups
###############################################################
resource "azurerm_monitor_alert_prometheus_rule_group" "this" {
  for_each = var.rule_groups

  name                = "${each.key}-${var.aks_cluster_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  cluster_name        = var.aks_cluster_name
  scopes              = [var.monitor_workspace_id, var.aks_cluster_id]
  interval            = each.value.interval
  rule_group_enabled  = each.value.enabled

  dynamic "rule" {
    for_each = each.value.alerts
    content {
      alert       = rule.key
      expression  = rule.value.expression
      for         = rule.value.for
      severity    = rule.value.severity
      enabled     = rule.value.enabled
      labels      = rule.value.labels
      annotations = rule.value.annotations

      dynamic "action" {
        for_each = local.action_group_ids
        content {
          action_group_id = action.value
        }
      }

      alert_resolution {
        auto_resolved   = true
        time_to_resolve = "PT15M"
      }
    }
  }

  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )

  lifecycle {
    precondition {
      condition     = length(local.action_group_ids) <= 5
      error_message = "Combined action_group_id + action_group_ids exceeds 5 (Azure hard limit per Prometheus alert rule)."
    }
  }
}
