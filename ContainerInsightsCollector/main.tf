###############################################################
# MODULE: ContainerInsightsCollector - Main
#
# DCR + DCRA pair shipping Container Insights streams from an AKS
# cluster to a Log Analytics Workspace via the ama-logs agent (the
# oms_agent addon, enabled separately on the cluster).
###############################################################

resource "time_static" "time" {}

locals {
  prefix   = "${var.subscription_acronym}-${var.environment}-${var.region_code}"
  dcr_name = "dcr-${local.prefix}-${var.workload}"

  # Container Insights destination name — referenced by data_flow.destinations.
  destination_name = "ciworkspace"

  # extension_json carries the ama-logs configuration (data collection
  # settings). Serialised here so callers don't have to fiddle with JSON.
  extension_json = jsonencode({
    dataCollectionSettings = {
      interval               = var.data_collection_settings.interval
      namespaceFilteringMode = var.data_collection_settings.namespace_filter_mode
      namespaces             = var.data_collection_settings.namespaces
      enableContainerLogV2   = var.data_collection_settings.enable_container_log_v2
    }
  })
}

###############################################################
# Data Collection Rule — Container Insights
###############################################################
resource "azurerm_monitor_data_collection_rule" "ci" {
  name                = local.dcr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = "Linux"

  destinations {
    log_analytics {
      workspace_resource_id = var.log_analytics_workspace_id
      name                  = local.destination_name
    }
  }

  data_flow {
    streams      = var.streams
    destinations = [local.destination_name]
  }

  data_sources {
    extension {
      name           = "ContainerInsightsExtension"
      extension_name = "ContainerInsights"
      streams        = var.streams
      extension_json = local.extension_json
    }
  }

  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}

###############################################################
# DCR Association — AKS cluster <-> DCR
#
# Unlike Managed Prometheus, Container Insights via LAW does NOT
# need a separate DCE association — the ama-logs agent talks
# directly to the LAW ingestion endpoint.
###############################################################
resource "azurerm_monitor_data_collection_rule_association" "ci" {
  name                    = "dcra-${local.prefix}-${var.workload}"
  target_resource_id      = var.aks_cluster_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.ci.id
  description             = "Container Insights — AKS cluster to LAW."
}
