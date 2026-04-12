###############################################################
# MODULE: KeyVault - Main
# Description: Azure Key Vault with lock and role assignments
# Note: Use the separate PrivateEndpoint module for PE
###############################################################

resource "time_static" "time" {}

data "azurerm_client_config" "current" {}

###############################################################
# Naming Convention
# Convention: kv-{subscription_acronym}-{environment}-{region_code}-{workload}
# Example:    kv-api-prod-gwc-apim
# WARNING: Max 24 characters!
###############################################################
locals {
  computed_name                    = "kv-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.workload}"
  name                             = var.name != null ? var.name : local.computed_name
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
}

###############################################################
# RESOURCE: Key Vault
###############################################################
resource "azurerm_key_vault" "this" {
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = coalesce(var.tenant_id, data.azurerm_client_config.current.tenant_id)
  sku_name            = var.sku_name

  rbac_authorization_enabled = var.enable_rbac

  enabled_for_disk_encryption     = var.enabled_for_disk_encryption
  enabled_for_deployment          = var.enabled_for_deployment
  enabled_for_template_deployment = var.enabled_for_template_deployment

  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled   = var.purge_protection_enabled

  public_network_access_enabled = var.public_network_access_enabled

  dynamic "network_acls" {
    for_each = var.network_acls != null ? [var.network_acls] : []
    content {
      default_action             = network_acls.value.default_action
      bypass                     = network_acls.value.bypass
      ip_rules                   = network_acls.value.ip_rules
      virtual_network_subnet_ids = network_acls.value.subnet_ids
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
  }
}

###############################################################
# RESOURCE: Management Lock
###############################################################
resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_key_vault.this.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}

###############################################################
# RESOURCE: RBAC — Current deployer (convenience)
###############################################################
resource "azurerm_role_assignment" "deployer" {
  count = var.assign_rbac_to_current_user ? 1 : 0

  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

###############################################################
# RESOURCE: Role Assignments
###############################################################
resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  scope                                  = azurerm_key_vault.this.id
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
