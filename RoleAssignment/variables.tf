###############################################################
# MODULE: RoleAssignment - Variables
#
# Thin generic wrapper around `azurerm_role_assignment`. Use for
# single, cross-sub RBAC grants where the caller knows the
# principal_id, the role, and the scope — typically:
#   - granting an AKS auto-created UAMI access on a cross-sub
#     resource (Application Routing on a DNS zone, Defender on a
#     LAW, etc.)
#   - granting a policy assignment's identity access to a target
#     scope (when not using PolicyAssignment's built-in
#     role_assignments input).
#
# For multiple role assignments tied to one policy assignment, use
# PolicyAssignment's `role_assignments` input instead.
###############################################################

variable "scope" {
  type        = string
  description = "Full Azure resource ID at which the role is granted (subscription, RG, or specific resource)."
  nullable    = false
}

variable "principal_id" {
  type        = string
  description = "Object ID of the principal receiving the role (UAMI principal_id, SP object_id, Entra group object_id, user object_id)."
  nullable    = false

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.principal_id))
    error_message = "principal_id must be a GUID (Object ID)."
  }
}

variable "principal_type" {
  type        = string
  description = "Type of the principal: User, Group, or ServicePrincipal. Setting this explicitly avoids AAD lookup races on first apply."
  default     = "ServicePrincipal"

  validation {
    condition     = contains(["User", "Group", "ServicePrincipal"], var.principal_type)
    error_message = "principal_type must be User, Group, or ServicePrincipal."
  }
}

variable "role_definition_name" {
  type        = string
  description = "Built-in or custom role display name (e.g. \"Private DNS Zone Contributor\"). Mutually exclusive with role_definition_id."
  default     = null
}

variable "role_definition_id" {
  type        = string
  description = "Role definition GUID or full resource ID. Use this when the role name is ambiguous OR when targeting a custom role. Mutually exclusive with role_definition_name."
  default     = null
}

variable "description" {
  type        = string
  description = "Free-text description of the role assignment (visible in the Azure portal). Useful to document why a grant exists."
  default     = null
}

variable "skip_service_principal_aad_check" {
  type        = bool
  description = "Skip the AAD existence check for the principal. Useful when the principal was just created (race on first apply)."
  default     = false
}
