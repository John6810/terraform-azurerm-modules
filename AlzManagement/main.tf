###############################################################
# Module AlzManagement - Log Analytics + Automation + Sentinel
###############################################################
# Wraps Azure/avm-ptn-alz-management/azurerm
# Creates: LAW, Automation Account, DCRs, Solutions, Sentinel,
#          User Assigned Identities (law, ama)
###############################################################

resource "time_static" "time" {}

###############################################################
# Optional: Inline Resource Group Creation
###############################################################
resource "azurerm_resource_group" "this" {
  count    = var.create_resource_group ? 1 : 0
  name     = "rg-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.resource_group_workload}"
  location = var.location
  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}

locals {
  resource_group_name = var.create_resource_group ? azurerm_resource_group.this[0].name : var.resource_group_name

  # Naming convention
  law_name     = "law-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.workload}"
  aa_name      = "aa-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.workload}"
  identity_law = "id-${var.subscription_acronym}-${var.environment}-${var.region_code}-law"
  identity_ama = "id-${var.subscription_acronym}-${var.environment}-${var.region_code}-ama"

  # SKU logic: CapacityReservation if > 100GB/day, else PerGB2018
  law_sku = var.log_ingestion_gb_per_day > 100 ? "CapacityReservation" : "PerGB2018"

  common_tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}

###############################################################
# User Assigned Identity for Log Analytics
###############################################################
resource "azurerm_user_assigned_identity" "law" {
  name                = local.identity_law
  location            = var.location
  resource_group_name = local.resource_group_name
  tags                = local.common_tags
}

###############################################################
# AVM ALZ Management Module
###############################################################
module "alz_management" {
  source = "Azure/avm-ptn-alz-management/azurerm"
  # Exact pin (mirror of AlzArchitecture's pinning style). Bump
  # deliberately when the upstream AVM module ships a new minor —
  # ALZ libraries can introduce breaking changes within 0.x.
  version = "0.9.0"

  location                        = var.location
  resource_group_name             = local.resource_group_name
  resource_group_creation_enabled = false

  # ── Log Analytics Workspace ──────────────────────────────────
  log_analytics_workspace_name                               = local.law_name
  log_analytics_workspace_sku                                = local.law_sku
  log_analytics_workspace_reservation_capacity_in_gb_per_day = local.law_sku == "CapacityReservation" ? var.log_ingestion_gb_per_day : null
  log_analytics_workspace_retention_in_days                  = var.log_retention_days
  log_analytics_workspace_daily_quota_gb                     = var.log_daily_quota_gb
  log_analytics_workspace_internet_ingestion_enabled         = var.law_internet_ingestion_enabled
  log_analytics_workspace_internet_query_enabled             = var.law_internet_query_enabled
  log_analytics_workspace_cmk_for_query_forced               = var.enable_cmk
  log_analytics_workspace_local_authentication_enabled       = var.law_local_authentication_enabled
  log_analytics_workspace_allow_resource_only_permissions    = true

  # ── Automation Account ───────────────────────────────────────
  automation_account_name                          = local.aa_name
  automation_account_sku_name                      = "Basic"
  automation_account_local_authentication_enabled  = false
  automation_account_public_network_access_enabled = var.aa_public_network_access_enabled
  automation_account_identity = {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.law.id]
  }
  linked_automation_account_creation_enabled = true

  # ── Data Collection Rules (Azure Monitor Agent) ──────────────
  data_collection_rules = {
    change_tracking = {
      name     = "dcr-${var.subscription_acronym}-${var.environment}-${var.region_code}-changetracking"
      location = var.location
    }
    vm_insights = {
      name     = "dcr-${var.subscription_acronym}-${var.environment}-${var.region_code}-vminsights"
      location = var.location
    }
    defender_sql = {
      name                                                   = "dcr-${var.subscription_acronym}-${var.environment}-${var.region_code}-defendersql"
      location                                               = var.location
      enable_collection_of_sql_queries_for_security_research = true
    }
  }

  # ── Log Analytics Solutions ──────────────────────────────────
  log_analytics_solution_plans = [
    { product = "OMSGallery/ChangeTracking", publisher = "Microsoft" },
    { product = "OMSGallery/VMInsights", publisher = "Microsoft" },
    { product = "OMSGallery/ContainerInsights", publisher = "Microsoft" },
  ]

  # ── Microsoft Sentinel ───────────────────────────────────────
  sentinel_onboarding = {
    customer_managed_key_enabled = var.enable_cmk
  }

  # ── User Assigned Managed Identities ─────────────────────────
  user_assigned_managed_identities = {
    ama = {
      name     = local.identity_ama
      location = var.location
    }
  }
}
