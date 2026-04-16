###############################################################
# MODULE: PrometheusAlertRules - Main
# Description: Prometheus alert rule groups for AKS clusters,
#              backed by Azure Monitor Workspace.
#              Supports multiple groups (Azure limit: 20 rules/group).
###############################################################

resource "time_static" "time" {}

###############################################################
# Naming Convention
###############################################################
locals {
  prefix = "${var.subscription_acronym}-${var.environment}-${var.region_code}"
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

      action {
        action_group_id = var.action_group_id
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
}
