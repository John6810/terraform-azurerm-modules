###############################################################
# MODULE: StorageAccount - Main
# Description: Azure Storage Account with lock and RBAC
###############################################################

resource "time_static" "time" {}

###############################################################
# Naming Convention
# Convention: st{subscription_acronym}{environment}{region_code}{workload}
# Note: lowercase alphanumeric only, 3-24 chars
# Example:    stapiprodgwcblob01
###############################################################
locals {
  computed_name                      = "st${var.subscription_acronym}${var.environment}${var.region_code}${var.workload}"
  name                               = var.name != null ? var.name : local.computed_name
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"

  # Merge caller-supplied identity_ids with the CMK UAMI (deduplicated).
  # The customer_managed_key block requires its UAMI to also be referenced
  # in the identity block — this is enforced automatically here.
  cmk_identity_ids = var.customer_managed_key != null ? [var.customer_managed_key.user_assigned_identity_id] : []
  all_identity_ids = distinct(concat(var.identity_ids, local.cmk_identity_ids))
}

###############################################################
# RESOURCE: Storage Account
###############################################################
resource "azurerm_storage_account" "this" {
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name

  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type
  account_kind             = var.account_kind

  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  public_network_access_enabled     = var.public_network_access_enabled
  shared_access_key_enabled         = var.shared_access_key_enabled
  default_to_oauth_authentication   = var.default_to_oauth_authentication
  cross_tenant_replication_enabled  = var.cross_tenant_replication_enabled
  infrastructure_encryption_enabled = var.infrastructure_encryption_enabled
  local_user_enabled                = var.local_user_enabled
  allow_nested_items_to_be_public   = false

  dynamic "identity" {
    for_each = var.identity_type != null ? [1] : []
    content {
      type         = var.identity_type
      identity_ids = length(local.all_identity_ids) > 0 ? local.all_identity_ids : null
    }
  }

  dynamic "customer_managed_key" {
    for_each = var.customer_managed_key != null ? [var.customer_managed_key] : []
    content {
      key_vault_key_id          = customer_managed_key.value.key_vault_key_id
      user_assigned_identity_id = customer_managed_key.value.user_assigned_identity_id
    }
  }

  dynamic "blob_properties" {
    # FileStorage (Premium Azure Files) doesn't support blob_properties
    for_each = var.account_kind != "FileStorage" && var.blob_delete_retention_days != null ? [1] : []
    content {
      versioning_enabled       = var.blob_versioning_enabled
      change_feed_enabled      = var.blob_change_feed_enabled
      last_access_time_enabled = var.blob_last_access_time_enabled

      delete_retention_policy {
        days = var.blob_delete_retention_days
      }
      container_delete_retention_policy {
        days = var.container_delete_retention_days
      }
    }
  }

  dynamic "azure_files_authentication" {
    for_each = var.azure_files_authentication != null ? [var.azure_files_authentication] : []
    content {
      directory_type                 = azure_files_authentication.value.directory_type
      default_share_level_permission = azure_files_authentication.value.default_share_level_permission
    }
  }

  dynamic "network_rules" {
    for_each = var.network_rules != null ? [var.network_rules] : []
    content {
      default_action             = network_rules.value.default_action
      bypass                     = network_rules.value.bypass
      virtual_network_subnet_ids = network_rules.value.virtual_network_subnet_ids
      ip_rules                   = network_rules.value.ip_rules
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
# RESOURCE: Storage Containers
###############################################################
resource "azurerm_storage_container" "this" {
  for_each = var.containers

  name                  = each.value.name
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = each.value.access_type
}

###############################################################
# RESOURCE: File Shares (Azure Files)
###############################################################
resource "azurerm_storage_share" "this" {
  for_each = var.file_shares

  name               = each.value.name
  storage_account_id = azurerm_storage_account.this.id
  quota              = each.value.quota_gb
  access_tier        = each.value.access_tier
}

###############################################################
# RESOURCE: Management Lock
###############################################################
resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_storage_account.this.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}

###############################################################
# RESOURCE: Role Assignments
###############################################################
resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  scope                                  = azurerm_storage_account.this.id
  principal_id                           = each.value.principal_id
  principal_type                         = each.value.principal_type
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  description                            = each.value.description
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
}
