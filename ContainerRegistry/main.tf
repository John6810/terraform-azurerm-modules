###############################################################
# MODULE: ContainerRegistry - Main
# Description: Azure Container Registry (ACR) with lock and RBAC
###############################################################

resource "time_static" "time" {}

###############################################################
# Naming Convention
# Convention: cr{subscription_acronym}{environment}{region_code}{workload}
# Note: ACR name must be alphanumeric only, no hyphens!
# Example:    crapiprodgwc001
###############################################################
locals {
  computed_name                      = "cr${var.subscription_acronym}${var.environment}${var.region_code}${var.workload}"
  name                               = var.name != null ? var.name : local.computed_name
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
}

###############################################################
# RESOURCE: Container Registry
###############################################################
resource "azurerm_container_registry" "this" {
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku

  admin_enabled                 = var.admin_enabled
  public_network_access_enabled = var.public_network_access_enabled
  zone_redundancy_enabled       = var.zone_redundancy_enabled
  data_endpoint_enabled         = var.data_endpoint_enabled

  # Premium-only security/lifecycle toggles. Azure rejects them on
  # Basic/Standard, so we set null when the SKU isn't Premium.
  retention_policy_in_days = var.sku == "Premium" ? var.retention_policy_in_days : null
  trust_policy_enabled     = var.sku == "Premium" ? var.trust_policy_enabled : null
  anonymous_pull_enabled   = var.anonymous_pull_enabled
  export_policy_enabled    = var.sku == "Premium" ? var.export_policy_enabled : null

  dynamic "identity" {
    for_each = length(var.identity_ids) > 0 ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = var.identity_ids
    }
  }

  dynamic "encryption" {
    for_each = var.customer_managed_key != null ? [var.customer_managed_key] : []
    content {
      key_vault_key_id   = encryption.value.key_vault_key_id
      identity_client_id = encryption.value.identity_client_id
    }
  }

  dynamic "georeplications" {
    for_each = var.georeplications
    content {
      location                = georeplications.value.location
      zone_redundancy_enabled = georeplications.value.zone_redundancy_enabled
      tags                    = georeplications.value.tags
    }
  }

  dynamic "network_rule_set" {
    for_each = var.network_rule_set != null ? [var.network_rule_set] : []
    content {
      default_action = network_rule_set.value.default_action
    }
  }

  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )

  lifecycle {
    prevent_destroy = true

    # Premium-only feature usage check at plan time. Caller can still
    # downgrade to Basic/Standard, but only when no Premium-only feature
    # is actively enabled.
    precondition {
      condition = var.sku == "Premium" || (
        var.customer_managed_key == null &&
        var.retention_policy_in_days == null &&
        var.trust_policy_enabled == false &&
        length(var.georeplications) == 0
      )
      error_message = "customer_managed_key, retention_policy_in_days, trust_policy_enabled and georeplications all require sku = \"Premium\". Set sku to Premium or unset these inputs."
    }

    # CMK requires at least one UAMI to read from Key Vault.
    precondition {
      condition     = var.customer_managed_key == null || length(var.identity_ids) > 0
      error_message = "customer_managed_key requires at least one entry in identity_ids (the User-Assigned MI granted Key Vault Crypto User on the KV)."
    }
  }
}

###############################################################
# RESOURCE: Diagnostic Setting (optional, single LAW destination)
###############################################################
resource "azurerm_monitor_diagnostic_setting" "this" {
  count = var.diagnostic_setting != null ? 1 : 0

  name                       = var.diagnostic_setting.name
  target_resource_id         = azurerm_container_registry.this.id
  log_analytics_workspace_id = var.diagnostic_setting.log_analytics_workspace_id

  dynamic "enabled_log" {
    for_each = var.diagnostic_setting.categories
    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = var.diagnostic_setting.metrics_enabled ? ["AllMetrics"] : []
    content {
      category = enabled_metric.value
    }
  }
}

###############################################################
# RESOURCE: Management Lock
###############################################################
resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_container_registry.this.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}

###############################################################
# RESOURCE: Role Assignments
###############################################################
resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  scope                                  = azurerm_container_registry.this.id
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
