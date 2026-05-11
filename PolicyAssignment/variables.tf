###############################################################
# MODULE: PolicyAssignment - Variables
# Creates Azure Policy assignments scoped to Resource Groups,
# Subscriptions, or Management Groups. Each assignment carries
# its own scope, so one deployment can cover multiple scopes
# in one apply (mirrors PolicyExemption pattern).
###############################################################

variable "assignments" {
  type = map(object({
    # ─── Scope — exactly ONE of the following must be set ────
    resource_group_id   = optional(string)
    subscription_id     = optional(string)
    management_group_id = optional(string)

    # ─── Assignment details ──────────────────────────────────
    policy_definition_id = string                          # accepts both individual policies and initiatives (policySetDefinitions)
    display_name         = string
    description          = optional(string)
    enforce              = optional(bool, true)
    parameters           = optional(map(any))              # caller passes { effect = "audit" }; module wraps each value as { value = ... }

    # ─── Managed identity (DeployIfNotExists/Modify) ─────────
    # Required when the policy/initiative contains DINE or Modify
    # effects. Audit/Deny-only assignments don't need an identity.
    identity_type     = optional(string)                   # "SystemAssigned" or "UserAssigned"
    identity_ids      = optional(list(string))             # required when identity_type = "UserAssigned"
    location          = optional(string)                   # required when identity_type is set

    non_compliance_messages = optional(list(object({
      content                        = string
      policy_definition_reference_id = optional(string)
    })), [])

    # ─── Role assignments for the assignment's identity (DINE/Modify) ────
    # Required when the policy/initiative needs to deploy or modify
    # resources outside its own scope (e.g. write to a central storage
    # account, attach flow logs on VNets). Each entry creates an
    # azurerm_role_assignment with principal_id = this assignment's
    # SystemAssigned identity.
    #
    # Specify exactly ONE of role_definition_name (built-in role) or
    # role_definition_id (custom role definition GUID).
    role_assignments = optional(list(object({
      scope                = string                          # full Azure resource ID at which to grant the role
      role_definition_name = optional(string)                # built-in role display name (e.g. "Contributor")
      role_definition_id   = optional(string)                # GUID for built-in or custom roles
    })), [])
  }))
  description = <<-EOT
  Map of policy assignments. Key = assignment name (must be unique within scope, max 24 chars).

  Exactly ONE scope must be set per assignment:
    - resource_group_id   : full RG resource ID
    - subscription_id     : full subscription path (/subscriptions/<guid>)
    - management_group_id : full MG resource ID

  Other fields:
    - policy_definition_id : full resource ID. Accepts both:
        /providers/Microsoft.Authorization/policyDefinitions/<id>      (single policy)
        /providers/Microsoft.Authorization/policySetDefinitions/<id>   (initiative)
    - parameters           : map of policy parameter name => value. Module wraps each value
                             as Azure Policy expects: { name = { value = <value> } }.
    - enforce              : false = "DoNotEnforce" mode (assignment exists but doesn't audit/deny).
    - identity_type        : SystemAssigned or UserAssigned. Required when policy uses DINE/Modify.
    - location             : required if identity_type is set.
    - non_compliance_messages : optional human-readable messages shown in compliance reports.
  EOT
  nullable    = false

  validation {
    condition = alltrue([
      for a in var.assignments :
      length(compact([
        try(a.resource_group_id, null),
        try(a.subscription_id, null),
        try(a.management_group_id, null),
      ])) == 1
    ])
    error_message = "Each assignment must set exactly ONE of resource_group_id, subscription_id, or management_group_id."
  }

  validation {
    condition = alltrue([
      for a in var.assignments :
      a.management_group_id == null || can(regex("^/providers/Microsoft\\.Management/managementGroups/[^/]+$", a.management_group_id))
    ])
    error_message = "management_group_id must be a valid Azure Management Group resource ID."
  }

  validation {
    condition = alltrue([
      for a in var.assignments :
      a.identity_type == null || contains(["SystemAssigned", "UserAssigned"], a.identity_type)
    ])
    error_message = "identity_type must be SystemAssigned or UserAssigned."
  }

  validation {
    condition = alltrue([
      for a in var.assignments :
      a.identity_type == null || a.location != null
    ])
    error_message = "location is required when identity_type is set."
  }
}
