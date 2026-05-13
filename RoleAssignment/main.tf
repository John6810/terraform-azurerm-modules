###############################################################
# MODULE: RoleAssignment - Main
# Thin wrapper around azurerm_role_assignment for single grants.
###############################################################

resource "azurerm_role_assignment" "this" {
  scope = var.scope

  role_definition_name = var.role_definition_name
  role_definition_id = (
    var.role_definition_id == null ? null :
    can(regex("^/", var.role_definition_id)) ? var.role_definition_id :
    "/providers/Microsoft.Authorization/roleDefinitions/${var.role_definition_id}"
  )

  principal_id                     = var.principal_id
  principal_type                   = var.principal_type
  description                      = var.description
  skip_service_principal_aad_check = var.skip_service_principal_aad_check
}
