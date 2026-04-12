###############################################################
# Module FinOpsHub
###############################################################
# Deploys the Microsoft FinOps Toolkit Hub infrastructure:
# Resource Group, ADLS Gen2 Storage, Azure Data Explorer,
# Data Factory, Event Grid, and RBAC assignments.
###############################################################

resource "time_static" "time" {}

locals {
  base       = "${var.subscription_acronym}-${var.environment}-${var.region_code}"
  rg_name    = "rg-${local.base}-finops"
  st_name    = "stfh${var.subscription_acronym}${var.environment}${var.region_code}01"
  adf_name   = "adf-${local.base}-finops"
  adx_name   = "adxfh${var.subscription_acronym}${var.environment}${var.region_code}01"
  evgt_name  = "evgt-${local.base}-finops"
  evhns_name = "evhns-${local.base}-finops"

  common_tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )

  containers = toset(["msexports", "ingestion", "config"])
}

###############################################################
# Resource Group
###############################################################
resource "azurerm_resource_group" "this" {
  name     = local.rg_name
  location = var.location
  tags     = local.common_tags
}

###############################################################
# Storage Account — ADLS Gen2
###############################################################
resource "azurerm_storage_account" "this" {
  name                            = local.st_name
  resource_group_name             = azurerm_resource_group.this.name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = var.storage_replication_type
  is_hns_enabled                  = true
  public_network_access_enabled   = var.enable_public_access
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  tags                            = local.common_tags
}

###############################################################
# Containers: msexports, ingestion, config
###############################################################
resource "azurerm_storage_container" "this" {
  for_each = local.containers

  name               = each.key
  storage_account_id = azurerm_storage_account.this.id
}

###############################################################
# settings.json — Hub configuration
###############################################################
resource "azurerm_storage_blob" "settings" {
  name                   = "settings.json"
  storage_account_name   = azurerm_storage_account.this.name
  storage_container_name = azurerm_storage_container.this["config"].name
  type                   = "Block"
  content_type           = "application/json"

  source_content = jsonencode({
    type      = "hub"
    version   = "0.12"
    learnMore = "https://aka.ms/finops/hubs"
    retention = {
      msexports = { days = var.export_retention_days }
      ingestion = { months = var.ingestion_retention_months }
    }
    scopes = []
  })
}

###############################################################
# Lifecycle policy — auto-cleanup of exports
###############################################################
resource "azurerm_storage_management_policy" "this" {
  storage_account_id = azurerm_storage_account.this.id

  dynamic "rule" {
    for_each = var.export_retention_days > 0 ? [1] : []
    content {
      name    = "cleanup-msexports"
      enabled = true
      filters {
        prefix_match = ["msexports/"]
        blob_types   = ["blockBlob"]
      }
      actions {
        base_blob {
          delete_after_days_since_creation_greater_than = var.export_retention_days
        }
      }
    }
  }

  rule {
    name    = "cleanup-ingestion"
    enabled = true
    filters {
      prefix_match = ["ingestion/"]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        delete_after_days_since_creation_greater_than = var.ingestion_retention_months * 31
      }
    }
  }
}
