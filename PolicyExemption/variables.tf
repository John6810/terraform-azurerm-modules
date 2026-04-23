###############################################################
# MODULE: PolicyExemption - Variables
# Creates Azure Policy exemptions scoped to Resource Groups,
# Subscriptions, or Management Groups.
# Each exemption carries its own scope, so one deployment can
# cover multiple scopes in one apply.
###############################################################

variable "exemptions" {
  type = map(object({
    # ─── Scope — exactly ONE of the following must be set ────
    resource_group_id   = optional(string)
    subscription_id     = optional(string)
    management_group_id = optional(string)

    # ─── Exemption details ──────────────────────────────────
    policy_assignment_id            = string
    exemption_category              = optional(string, "Waiver")
    display_name                    = string
    description                     = optional(string)
    expires_on                      = optional(string)
    policy_definition_reference_ids = optional(list(string))
    metadata                        = optional(map(string))
  }))
  description = <<-EOT
  Map of policy exemptions. Key = exemption name (must be unique within scope).

  Exactly ONE of these must be set per exemption:
    - resource_group_id   : full RG resource ID
    - subscription_id     : subscription ID (GUID or full sub path)
    - management_group_id : full MG resource ID

  Other fields:
    - policy_assignment_id            : full resource ID of the policy assignment to exempt.
    - exemption_category              : 'Waiver' (accept risk) or 'Mitigated' (compensating control).
    - display_name                    : human-readable name shown in the portal.
    - description                     : justification — MANDATORY for audit trail.
    - expires_on                      : RFC3339 timestamp. Without it, exemption is permanent.
    - policy_definition_reference_ids : for initiative-scoped assignments, list of specific child
                                         policies to exempt. Empty = exempt all child policies.
    - metadata                        : free-form tags (owner, ticket ID, etc.).
  EOT
  nullable    = false

  validation {
    condition = alltrue([
      for e in var.exemptions :
      length(compact([
        try(e.resource_group_id, null),
        try(e.subscription_id, null),
        try(e.management_group_id, null),
      ])) == 1
    ])
    error_message = "Each exemption must set exactly ONE of resource_group_id, subscription_id, or management_group_id."
  }

  validation {
    condition = alltrue([
      for e in var.exemptions :
      e.resource_group_id == null || can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+$", e.resource_group_id))
    ])
    error_message = "resource_group_id must be a valid Azure Resource Group resource ID."
  }

  validation {
    condition = alltrue([
      for e in var.exemptions :
      e.management_group_id == null || can(regex("^/providers/Microsoft\\.Management/managementGroups/[^/]+$", e.management_group_id))
    ])
    error_message = "management_group_id must be a valid Azure Management Group resource ID."
  }

  validation {
    condition = alltrue([
      for e in var.exemptions : contains(["Waiver", "Mitigated"], e.exemption_category)
    ])
    error_message = "exemption_category must be either 'Waiver' or 'Mitigated'."
  }
}
