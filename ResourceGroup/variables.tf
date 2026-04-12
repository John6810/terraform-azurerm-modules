###############################################################
# MODULE: ResourceGroup - Variables
###############################################################

###############################################################
# NAMING CONVENTION
###############################################################
variable "name" {
  type        = string
  default     = null
  description = "Optional. Explicit resource group name. If null, computed from naming components."

  validation {
    condition     = var.name == null || can(regex("^[a-zA-Z0-9_().-]{1,89}[a-zA-Z0-9_()-]$", var.name))
    error_message = <<ERROR_MESSAGE
    The resource group name must meet the following requirements:
    - `Between 1 and 90 characters long.`
    - `Can only contain Alphanumerics, underscores, parentheses, hyphens, periods.`
    - `Cannot end in a period`
    ERROR_MESSAGE
  }
}

variable "subscription_acronym" {
  type        = string
  default     = null
  description = "Subscription acronym for naming convention (e.g. mgm, con, idn, sec)"

  validation {
    condition     = var.subscription_acronym == null || can(regex("^[a-z]{2,5}$", var.subscription_acronym))
    error_message = "subscription_acronym must be 2 to 5 lowercase letters."
  }
}

variable "environment" {
  type        = string
  default     = null
  description = "Environment for naming convention (e.g. prod, nprd). Automatically injected by root.hcl."

  validation {
    condition     = var.environment == null || can(regex("^[a-z]{2,4}$", var.environment))
    error_message = "environment must be 2 to 4 lowercase letters."
  }
}

variable "region_code" {
  type        = string
  default     = null
  description = "Region code for naming convention (e.g. gwc, weu). Automatically injected by root.hcl."

  validation {
    condition     = var.region_code == null || can(regex("^[a-z]{2,5}$", var.region_code))
    error_message = "region_code must be 2 to 5 lowercase letters."
  }
}

variable "workload" {
  type        = string
  default     = null
  description = "Workload name for naming convention (e.g. management, network, identity)"

  validation {
    condition     = var.workload == null || can(regex("^[a-z][a-z0-9_-]{1,30}$", var.workload))
    error_message = "workload must be 2 to 31 characters: lowercase letters, digits, hyphens, underscores."
  }
}

###############################################################
# REQUIRED VARIABLES
###############################################################
variable "location" {
  type        = string
  description = "Azure region where the resource group will be deployed."
  nullable    = false
}

###############################################################
# OPTIONAL VARIABLES
###############################################################
variable "tags" {
  type        = map(string)
  description = "Tags to assign to the resource group. Merged with auto-generated CreatedOn tag."
  default     = {}
}

variable "lock" {
  type = object({
    kind = string
    name = optional(string)
  })
  default     = null
  description = <<-EOT
  Controls the Resource Lock configuration for this resource.

  - `kind` - (Required) The type of lock. Possible values are "CanNotDelete" and "ReadOnly".
  - `name` - (Optional) The name of the lock. If not specified, generated from the kind value.
  EOT

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "Lock kind must be either \"CanNotDelete\" or \"ReadOnly\"."
  }
}

variable "role_assignments" {
  description = <<-EOT
  A map of role assignments to create on this resource group. The map key is deliberately
  arbitrary to avoid issues where map keys may be unknown at plan time.

  - `role_definition_id_or_name`             - (Required) The ID or name of the role definition.
  - `principal_id`                           - (Required) The ID of the principal to assign the role to.
  - `principal_type`                         - (Optional) The type of principal. Values: User, Group, ServicePrincipal.
  - `condition`                              - (Optional) ABAC condition for the role assignment.
  - `condition_version`                      - (Optional) Condition version. Valid values: "2.0".
  - `description`                            - (Optional) Description of the role assignment.
  - `skip_service_principal_aad_check`       - (Optional) Skip AAD check for the service principal.
  - `delegated_managed_identity_resource_id` - (Optional) Delegated managed identity for cross-tenant scenarios.
  EOT
  type = map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    principal_type                         = optional(string)
    condition                              = optional(string)
    condition_version                      = optional(string)
    description                            = optional(string)
    skip_service_principal_aad_check       = optional(bool, false)
    delegated_managed_identity_resource_id = optional(string)
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for ra in var.role_assignments :
      can(regex("^/providers/Microsoft\\.Authorization/roleDefinitions/[0-9a-fA-F-]+$", ra.role_definition_id_or_name))
      ||
      can(regex("^[[:alpha:]]+", ra.role_definition_id_or_name))
    ])
    error_message = <<-EOT
    role_definition_id_or_name must be either:
      - A role definition ID: /providers/Microsoft.Authorization/roleDefinitions/<role-guid>
      - A role name: Reader, Contributor, "Storage Blob Data Reader", etc.
    EOT
  }
}
