###############################################################
# MODULE: KeyVaultStack - Main
# Description: Resource Group + Key Vault + Private Endpoint
#
# Note: KeyVault/PrivateEndpoint/ResourceGroup modules cannot be
#       called as child modules because Terragrunt only copies
#       the module folder into its cache. So we use resources
#       directly, following the same patterns.
###############################################################

data "azurerm_client_config" "current" {}

resource "time_static" "time" {}

locals {
  prefix = "${var.subscription_acronym}-${var.environment}-${var.region_code}"

  kv_suffix = var.kv_suffix != null ? var.kv_suffix : var.workload

  rg_name = "rg-${local.prefix}-${var.workload}"
  kv_name = var.kv_name != null ? var.kv_name : "kv-${local.prefix}-${local.kv_suffix}"
  pe_name = "pep-${local.prefix}-kv-${local.kv_suffix}"

  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"

  common_tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}

###############################################################
# RESOURCE: Resource Group
###############################################################
resource "azurerm_resource_group" "this" {
  name     = local.rg_name
  location = var.location
  tags     = local.common_tags
}

###############################################################
# RESOURCE: Resource Group — Management Lock
###############################################################
resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_resource_group.this.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}

###############################################################
# RESOURCE: Resource Group — Role Assignments
###############################################################
resource "azurerm_role_assignment" "rg" {
  for_each = var.role_assignments

  scope                                  = azurerm_resource_group.this.id
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

###############################################################
# RESOURCE: Key Vault
###############################################################
resource "azurerm_key_vault" "this" {
  name                = local.kv_name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
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

  tags = local.common_tags

  lifecycle {
    prevent_destroy = true

    precondition {
      condition     = length(local.kv_name) >= 3 && length(local.kv_name) <= 24
      error_message = "Computed Key Vault name '${local.kv_name}' is ${length(local.kv_name)} chars; must be 3-24. Reduce subscription_acronym/region_code/workload, or pass a shorter kv_suffix, or override via kv_name."
    }
  }
}

###############################################################
# RESOURCE: RBAC — Current deployer (convenience)
###############################################################
resource "azurerm_role_assignment" "kv_admin" {
  count = var.assign_rbac_to_current_user ? 1 : 0

  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

###############################################################
# RESOURCE: Private Endpoint
###############################################################
resource "azurerm_private_endpoint" "this" {
  name                = local.pe_name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = var.subnet_id

  custom_network_interface_name = var.pe_custom_network_interface_name

  private_service_connection {
    name                           = "psc-${local.pe_name}"
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  dynamic "ip_configuration" {
    for_each = var.pe_private_ip_address != null ? [1] : []
    content {
      name               = "ipc-${local.pe_name}"
      private_ip_address = var.pe_private_ip_address
      subresource_name   = "vault"
      member_name        = "default"
    }
  }

  dynamic "private_dns_zone_group" {
    for_each = var.private_dns_zone_ids != null ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = var.private_dns_zone_ids
    }
  }

  # Ignore private_dns_zone_group managed by ALZ DINE Policy
  lifecycle {
    ignore_changes = [private_dns_zone_group]
  }

  tags = merge(
    local.common_tags,
    {
      TargetResource  = azurerm_key_vault.this.id
      SubresourceType = "vault"
    }
  )
}

###############################################################
# DATA: Private Endpoint Connection (for IP retrieval)
###############################################################
data "azurerm_private_endpoint_connection" "this" {
  name                = azurerm_private_endpoint.this.name
  resource_group_name = azurerm_resource_group.this.name

  depends_on = [azurerm_private_endpoint.this]
}
