###############################################################
# MODULE: RbacAssignments - Variables
# Two assignment types:
#   group_assignments    → resolves Entra ID group by display_name
#   identity_assignments → uses principal_id directly (MI, SP)
###############################################################

variable "group_assignments" {
  description = <<-EOT
  A map of role assignments for Entra ID groups (resolved by display_name).
  The map key is deliberately arbitrary to avoid plan-time issues.

  - `group_name`                 - (Required) Entra ID group display name.
  - `scope`                      - (Required) Azure resource ID to assign the role on.
  - `role_definition_id_or_name` - (Required) Role definition ID or name.
  - `condition`                  - (Optional) ABAC condition.
  - `condition_version`          - (Optional) Condition version ("2.0").
  - `description`                - (Optional) Assignment description.
  EOT
  type = map(object({
    group_name                 = string
    scope                      = string
    role_definition_id_or_name = string
    condition                  = optional(string)
    condition_version          = optional(string)
    description                = optional(string)
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for a in var.group_assignments :
      can(regex("^/subscriptions/", a.scope))
    ])
    error_message = "Each scope must be a valid Azure resource ID starting with /subscriptions/."
  }
}

variable "identity_assignments" {
  description = <<-EOT
  A map of role assignments for any Entra principal (MI, SP, Group, User) — addressed by object ID.
  The map key is deliberately arbitrary to avoid plan-time issues.

  - `principal_id`                     - (Required) Object ID of the principal.
  - `scope`                            - (Required) Azure resource ID to assign the role on.
  - `role_definition_id_or_name`       - (Required) Role definition ID or name.
  - `principal_type`                   - (Optional) "User" | "Group" | "ServicePrincipal". Required when
                                         assigning to a group (Azure rejects with UnmatchedPrincipalType).
  - `condition`                        - (Optional) ABAC condition.
  - `condition_version`                - (Optional) Condition version ("2.0").
  - `description`                      - (Optional) Assignment description.
  - `skip_service_principal_aad_check` - (Optional) Skip AAD check. Defaults to false.
  EOT
  type = map(object({
    principal_id                     = string
    scope                            = string
    role_definition_id_or_name       = string
    principal_type                   = optional(string)
    condition                        = optional(string)
    condition_version                = optional(string)
    description                      = optional(string)
    skip_service_principal_aad_check = optional(bool, false)
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for a in var.identity_assignments :
      can(regex("^/subscriptions/", a.scope))
    ])
    error_message = "Each scope must be a valid Azure resource ID starting with /subscriptions/."
  }

  validation {
    condition = alltrue([
      for a in var.identity_assignments :
      a.principal_type == null || contains(["User", "Group", "ServicePrincipal", "ForeignGroup", "Device"], a.principal_type)
    ])
    error_message = "principal_type must be one of: User, Group, ServicePrincipal, ForeignGroup, Device."
  }
}
