###############################################################
# MODULE: PolicyExemption - Main
# Creates one azurerm_resource_group_policy_exemption per entry
# in var.exemptions.
###############################################################

resource "azurerm_resource_group_policy_exemption" "this" {
  for_each = var.exemptions

  name                            = each.key
  resource_group_id               = var.resource_group_id
  policy_assignment_id            = each.value.policy_assignment_id
  exemption_category              = each.value.exemption_category
  display_name                    = each.value.display_name
  description                     = each.value.description
  expires_on                      = each.value.expires_on
  policy_definition_reference_ids = each.value.policy_definition_reference_ids
  metadata                        = each.value.metadata != null ? jsonencode(each.value.metadata) : null
}
