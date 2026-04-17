###############################################################
# MODULE: FlowLogs - Main
# Description: VNet Flow Logs with optional Traffic Analytics.
#              One azurerm_network_watcher_flow_log per VNet.
###############################################################

resource "time_static" "time" {}

###############################################################
# Naming Convention
# Flow log name: fl-{subscription_acronym}-{environment}-{region_code}-{vnet_key}
###############################################################
locals {
  prefix = "${var.subscription_acronym}-${var.environment}-${var.region_code}"
}

###############################################################
# RESOURCE: VNet Flow Logs
###############################################################
resource "azurerm_network_watcher_flow_log" "this" {
  for_each = var.vnets

  name                      = "fl-${local.prefix}-${each.key}"
  location                  = var.location
  resource_group_name       = var.network_watcher_resource_group_name
  network_watcher_name      = var.network_watcher_name
  target_resource_id        = each.value.id
  storage_account_id        = var.storage_account_id
  enabled                   = each.value.enabled
  version                   = 2

  retention_policy {
    enabled = var.retention_days > 0
    days    = var.retention_days
  }

  dynamic "traffic_analytics" {
    for_each = var.traffic_analytics != null ? [var.traffic_analytics] : []
    content {
      enabled               = traffic_analytics.value.enabled
      workspace_id          = traffic_analytics.value.workspace_id
      workspace_region      = traffic_analytics.value.workspace_region
      workspace_resource_id = traffic_analytics.value.workspace_resource_id
      interval_in_minutes   = traffic_analytics.value.interval_minutes
    }
  }

  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}
