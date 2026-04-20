###############################################################
# MODULE: PolicyExemption - Variables
# Creates Azure Policy exemptions scoped to a Resource Group.
###############################################################

variable "resource_group_id" {
  type        = string
  description = "Full resource ID of the Resource Group where exemptions apply."
  nullable    = false

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+$", var.resource_group_id))
    error_message = "resource_group_id must be a valid Azure Resource Group resource ID."
  }
}

variable "exemptions" {
  type = map(object({
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

  - policy_assignment_id            : full resource ID of the policy assignment to exempt.
  - exemption_category              : 'Waiver' (accept risk) or 'Mitigated' (compensating control).
  - display_name                    : human-readable name shown in the portal.
  - description                     : justification — MANDATORY for audit trail, even if type is optional.
  - expires_on                      : RFC3339 timestamp. Without it, exemption is permanent (risky).
  - policy_definition_reference_ids : for initiative-scoped assignments, list of specific child
                                       policies to exempt. Empty = exempt all child policies.
  - metadata                        : free-form tags (owner, ticket ID, etc.).
  EOT
  nullable    = false

  validation {
    condition = alltrue([
      for e in var.exemptions : contains(["Waiver", "Mitigated"], e.exemption_category)
    ])
    error_message = "exemption_category must be either 'Waiver' or 'Mitigated'."
  }
}
