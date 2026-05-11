###############################################################
# MODULE: PolicyAssignment - Main
# Creates one policy assignment per entry in var.assignments,
# dispatched to the correct azurerm resource based on the scope
# (RG / Subscription / Management Group).
###############################################################

locals {
  rg_assignments  = { for k, v in var.assignments : k => v if v.resource_group_id != null }
  sub_assignments = { for k, v in var.assignments : k => v if v.subscription_id != null }
  mg_assignments  = { for k, v in var.assignments : k => v if v.management_group_id != null }

  # Wrap caller-friendly parameters { effect = "audit" } into Azure Policy
  # expected format { effect = { value = "audit" } }.
  wrap_parameters = {
    for k, v in var.assignments : k => (
      v.parameters == null ? null : jsonencode({
        for pk, pv in v.parameters : pk => { value = pv }
      })
    )
  }
}

###############################################################
# RG-scoped assignments
###############################################################
resource "azurerm_resource_group_policy_assignment" "this" {
  for_each = local.rg_assignments

  name                 = each.key
  resource_group_id    = each.value.resource_group_id
  policy_definition_id = each.value.policy_definition_id
  display_name         = each.value.display_name
  description          = each.value.description
  enforce              = each.value.enforce
  parameters           = local.wrap_parameters[each.key]
  location             = each.value.location

  dynamic "identity" {
    for_each = each.value.identity_type != null ? [1] : []
    content {
      type         = each.value.identity_type
      identity_ids = each.value.identity_type == "UserAssigned" ? each.value.identity_ids : null
    }
  }

  dynamic "non_compliance_message" {
    for_each = each.value.non_compliance_messages
    content {
      content                        = non_compliance_message.value.content
      policy_definition_reference_id = non_compliance_message.value.policy_definition_reference_id
    }
  }
}

###############################################################
# Subscription-scoped assignments
###############################################################
resource "azurerm_subscription_policy_assignment" "this" {
  for_each = local.sub_assignments

  name                 = each.key
  subscription_id      = each.value.subscription_id
  policy_definition_id = each.value.policy_definition_id
  display_name         = each.value.display_name
  description          = each.value.description
  enforce              = each.value.enforce
  parameters           = local.wrap_parameters[each.key]
  location             = each.value.location

  dynamic "identity" {
    for_each = each.value.identity_type != null ? [1] : []
    content {
      type         = each.value.identity_type
      identity_ids = each.value.identity_type == "UserAssigned" ? each.value.identity_ids : null
    }
  }

  dynamic "non_compliance_message" {
    for_each = each.value.non_compliance_messages
    content {
      content                        = non_compliance_message.value.content
      policy_definition_reference_id = non_compliance_message.value.policy_definition_reference_id
    }
  }
}

###############################################################
# Management Group-scoped assignments
###############################################################
resource "azurerm_management_group_policy_assignment" "this" {
  for_each = local.mg_assignments

  name                 = each.key
  management_group_id  = each.value.management_group_id
  policy_definition_id = each.value.policy_definition_id
  display_name         = each.value.display_name
  description          = each.value.description
  enforce              = each.value.enforce
  parameters           = local.wrap_parameters[each.key]
  location             = each.value.location

  dynamic "identity" {
    for_each = each.value.identity_type != null ? [1] : []
    content {
      type         = each.value.identity_type
      identity_ids = each.value.identity_type == "UserAssigned" ? each.value.identity_ids : null
    }
  }

  dynamic "non_compliance_message" {
    for_each = each.value.non_compliance_messages
    content {
      content                        = non_compliance_message.value.content
      policy_definition_reference_id = non_compliance_message.value.policy_definition_reference_id
    }
  }
}

###############################################################
# Role assignments for the policy assignments' identities
# ─────────────────────────────────────────────────────────────
# Flatten the per-assignment role_assignments list into a single
# map with stable composite keys (assignment_name + index). Each
# entry grants the corresponding policy assignment's identity the
# specified role at the specified scope.
#
# Required when DINE/Modify policies need to write resources outside
# their own scope (e.g. cross-sub storage, central monitoring LAW).
# Built-in policies declare what roles their identity needs in
# `roleDefinitionIds` — callers must surface them here.
#
# `time_sleep.role_assignment_propagation` gives Entra ID 60 s to
# propagate the new role assignments before the policy engine's
# first evaluation. Without it, the initial deploy can race the
# RBAC propagation and fail with 403 Forbidden.
###############################################################
locals {
  role_assignments_flat = flatten([
    for k, v in var.assignments : [
      for idx, ra in v.role_assignments : {
        key            = "${k}-${idx}"
        assignment_key = k
        scope          = ra.scope
        role_name      = ra.role_definition_name
        role_id        = ra.role_definition_id
      }
    ]
  ])

  role_assignments_map = { for entry in local.role_assignments_flat : entry.key => entry }
}

resource "azurerm_role_assignment" "policy_identity" {
  for_each = local.role_assignments_map

  scope = each.value.scope

  role_definition_name = each.value.role_name
  role_definition_id = (
    each.value.role_id == null ? null :
    can(regex("^/", each.value.role_id)) ? each.value.role_id :
    "/providers/Microsoft.Authorization/roleDefinitions/${each.value.role_id}"
  )

  principal_id = coalesce(
    try(azurerm_subscription_policy_assignment.this[each.value.assignment_key].identity[0].principal_id, null),
    try(azurerm_resource_group_policy_assignment.this[each.value.assignment_key].identity[0].principal_id, null),
    try(azurerm_management_group_policy_assignment.this[each.value.assignment_key].identity[0].principal_id, null),
  )

  principal_type = "ServicePrincipal"
}

resource "time_sleep" "role_assignment_propagation" {
  count = length(local.role_assignments_map) > 0 ? 1 : 0

  depends_on      = [azurerm_role_assignment.policy_identity]
  create_duration = "60s"

  triggers = {
    role_ids = jsonencode([for ra in azurerm_role_assignment.policy_identity : ra.id])
  }
}
