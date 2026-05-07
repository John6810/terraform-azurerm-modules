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
