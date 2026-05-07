###############################################################
# MODULE: ResourceGroupSet - Main
# Description: Creates N Azure Resource Groups in one apply,
#              each with its own optional lock and role assignments.
#
# Note: Cannot delegate to the ResourceGroup module because
#       Terragrunt copies only the source folder into its cache,
#       so child-module references do not resolve. Resource
#       blocks here mirror the ResourceGroup module 1:1, just
#       with for_each. Keep them in sync if ResourceGroup evolves.
###############################################################

resource "time_static" "time" {}

###############################################################
# Naming Convention
# Convention: rg-{subscription_acronym}-{environment}-{region_code}-{workload}
# Example:    rg-shc-nprd-gwc-network
###############################################################
locals {
  # Per-RG region_code override falls back to the set-level value.
  # Allows mixing regions in one set (e.g. GWC RGs alongside WEU RGs for
  # workloads with control planes hosted in a different region).
  effective_region_codes = {
    for k, rg in var.resource_groups :
    k => coalesce(rg.region_code, var.region_code)
  }

  effective_locations = {
    for k, rg in var.resource_groups :
    k => coalesce(rg.location, var.location)
  }

  computed_names = {
    for k, rg in var.resource_groups :
    k => rg.name != null ? rg.name : "rg-${var.subscription_acronym}-${var.environment}-${local.effective_region_codes[k]}-${rg.workload}"
  }

  common_tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )

  # Flatten role assignments to a single map keyed by "<rg_key>|<ra_key>"
  # so a single azurerm_role_assignment.this for_each handles everything.
  role_assignments_flat = merge([
    for rg_key, rg in var.resource_groups : {
      for ra_key, ra in rg.role_assignments :
      "${rg_key}|${ra_key}" => merge(ra, { rg_key = rg_key })
    }
  ]...)

  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
}

###############################################################
# RESOURCE: Resource Groups
###############################################################
resource "azurerm_resource_group" "this" {
  for_each = var.resource_groups

  name     = local.computed_names[each.key]
  location = local.effective_locations[each.key]

  tags = merge(local.common_tags, each.value.tags)
}

###############################################################
# RESOURCE: Management Locks (per-RG, optional)
###############################################################
resource "azurerm_management_lock" "this" {
  for_each = {
    for k, rg in var.resource_groups : k => rg
    if rg.lock != null
  }

  lock_level = each.value.lock.kind
  name       = coalesce(each.value.lock.name, "lock-${each.value.lock.kind}")
  scope      = azurerm_resource_group.this[each.key].id
  notes      = each.value.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}

###############################################################
# RESOURCE: Role Assignments (per-RG, optional)
###############################################################
resource "azurerm_role_assignment" "this" {
  for_each = local.role_assignments_flat

  scope                                  = azurerm_resource_group.this[each.value.rg_key].id
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
