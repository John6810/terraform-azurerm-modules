###############################################################
# MODULE: ResourceGroup - Main
# Description: Azure Resource Group with locks and role assignments
###############################################################

resource "time_static" "time" {}

###############################################################
# Naming Convention
# Convention: rg-{subscription_acronym}-{environment}-{region_code}-{workload}
# Example:    rg-mgm-nprd-gwc-management
###############################################################
locals {
  computed_name                    = "rg-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.workload}"
  name                             = var.name != null ? var.name : local.computed_name
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
}

###############################################################
# RESOURCE: Resource Group
###############################################################
resource "azurerm_resource_group" "this" {
  name     = local.name
  location = var.location

  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}

###############################################################
# RESOURCE: Management Lock
###############################################################
resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_resource_group.this.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}

###############################################################
# RESOURCE: Role Assignments
###############################################################
resource "azurerm_role_assignment" "this" {
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
