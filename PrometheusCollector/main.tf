###############################################################
# MODULE: PrometheusCollector - Main
# Description: DCR + Associations to send Prometheus metrics
#              from an AKS cluster to an Azure Monitor Workspace
###############################################################

resource "time_static" "time" {}

###############################################################
# Naming Convention
###############################################################
locals {
  prefix   = "${var.subscription_acronym}-${var.environment}-${var.region_code}"
  dcr_name = "dcr-${local.prefix}-${var.workload}"
}

###############################################################
# RESOURCE: Data Collection Rule — Prometheus Forwarder
###############################################################
resource "azurerm_monitor_data_collection_rule" "prometheus" {
  name                        = local.dcr_name
  resource_group_name         = var.resource_group_name
  location                    = var.location
  data_collection_endpoint_id = var.data_collection_endpoint_id
  kind                        = "Linux"

  destinations {
    monitor_account {
      monitor_account_id = var.monitor_workspace_id
      name               = "MonitoringAccount"
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["MonitoringAccount"]
  }

  data_sources {
    prometheus_forwarder {
      streams = ["Microsoft-PrometheusMetrics"]
      name    = "PrometheusDataSource"
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
# RESOURCE: DCE Association — AKS <-> Data Collection Endpoint
# Name MUST be "configurationAccessEndpoint"
###############################################################
resource "azurerm_monitor_data_collection_rule_association" "dce" {
  name                        = "configurationAccessEndpoint"
  target_resource_id          = var.aks_cluster_id
  data_collection_endpoint_id = var.data_collection_endpoint_id
}

###############################################################
# RESOURCE: DCR Association — AKS <-> Data Collection Rule
###############################################################
resource "azurerm_monitor_data_collection_rule_association" "prometheus" {
  name                    = "dcra-${local.prefix}-${var.workload}"
  target_resource_id      = var.aks_cluster_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.prometheus.id
}
