###############################################################
# MODULE: ManagedIdentity - Main
# Description: User Assigned Managed Identity Azure
###############################################################

resource "time_static" "time" {}

###############################################################
# Naming Convention
# Convention: id-{subscription_acronym}-{environment}-{region_code}-{workload}
# Example:    id-api-prod-gwc-aks
###############################################################
locals {
  computed_name                      = "id-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.workload}"
  name                               = var.name != null ? var.name : local.computed_name
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
}

###############################################################
# RESOURCE: User Assigned Managed Identity
###############################################################
resource "azurerm_user_assigned_identity" "this" {
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name

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
  scope      = azurerm_user_assigned_identity.this.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}

###############################################################
# RESOURCE: Federated Identity Credentials (Workload Identity)
###############################################################
resource "azurerm_federated_identity_credential" "this" {
  for_each = var.federated_identity_credentials

  name                      = each.value.name
  user_assigned_identity_id = azurerm_user_assigned_identity.this.id
  audience                  = each.value.audience
  issuer                    = each.value.issuer
  subject                   = each.value.subject
}

###############################################################
# RESOURCE: Role Assignments
###############################################################
resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  principal_id                           = azurerm_user_assigned_identity.this.principal_id
  scope                                  = each.value.scope
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  description                            = each.value.description
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}
