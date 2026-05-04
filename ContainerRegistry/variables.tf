###############################################################
# MODULE: ContainerRegistry - Variables
###############################################################

###############################################################
# NAMING CONVENTION
# ACR name: alphanumeric only, no hyphens! 5-50 chars
# Convention: cr{subscription_acronym}{environment}{region_code}{workload}
###############################################################
variable "name" {
  type        = string
  default     = null
  description = "Explicit registry name. If null, computed automatically."

  validation {
    condition     = var.name == null || can(regex("^[a-zA-Z0-9]{5,50}$", var.name))
    error_message = "ACR name must be 5-50 alphanumeric characters (no hyphens)."
  }
}

variable "subscription_acronym" {
  type        = string
  default     = null
  description = "Subscription acronym (e.g. api, mgm)"

  validation {
    condition     = var.subscription_acronym == null || can(regex("^[a-z]{2,5}$", var.subscription_acronym))
    error_message = "subscription_acronym must be 2 to 5 lowercase letters."
  }
}

variable "environment" {
  type        = string
  default     = null
  description = "Environment (e.g. prod, nprd)"

  validation {
    condition     = var.environment == null || can(regex("^[a-z]{2,4}$", var.environment))
    error_message = "environment must be 2 to 4 lowercase letters."
  }
}

variable "region_code" {
  type        = string
  default     = null
  description = "Region code (e.g. gwc, weu)"

  validation {
    condition     = var.region_code == null || can(regex("^[a-z]{2,5}$", var.region_code))
    error_message = "region_code must be 2 to 5 lowercase letters."
  }
}

variable "workload" {
  type        = string
  default     = null
  description = "Workload name (e.g. 001). No hyphens — ACR names are alphanumeric only."

  validation {
    condition     = var.workload == null || can(regex("^[a-z][a-z0-9]{0,15}$", var.workload))
    error_message = "workload must be 1-16 alphanumeric characters (no hyphens for ACR)."
  }
}

###############################################################
# REQUIRED VARIABLES
###############################################################
variable "location" {
  type        = string
  description = "Azure region"
  nullable    = false
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name"
  nullable    = false
}

###############################################################
# ACR CONFIGURATION
###############################################################
variable "sku" {
  type        = string
  description = "Registry SKU: Basic, Standard, Premium"
  default     = "Premium"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "SKU must be Basic, Standard, or Premium."
  }
}

variable "admin_enabled" {
  type        = bool
  description = "Enable admin account (not recommended in production)"
  default     = false
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Enable public network access"
  default     = false
}

variable "zone_redundancy_enabled" {
  type        = bool
  description = "Enable zone redundancy (Premium only)"
  default     = true
}

variable "data_endpoint_enabled" {
  type        = bool
  description = "Enable data endpoint (Premium only, required for PE)"
  default     = true
}

variable "georeplications" {
  description = "Geo-replication configuration (Premium only)"
  type = list(object({
    location                = string
    zone_redundancy_enabled = optional(bool, true)
    tags                    = optional(map(string), {})
  }))
  default = []
}

variable "network_rule_set" {
  description = "Network rule set configuration"
  type = object({
    default_action = optional(string, "Deny")
  })
  default = null
}

###############################################################
# SECURITY HARDENING (Premium SKU)
###############################################################
variable "anonymous_pull_enabled" {
  description = "Allow unauthenticated repository read access. Default false (security best-practice)."
  type        = bool
  default     = false
}

variable "export_policy_enabled" {
  description = "Allow exporting repository metadata. Microsoft default is true; flip to false to prevent exfiltration via export. Premium SKU."
  type        = bool
  default     = true
}

variable "retention_policy_in_days" {
  description = "Number of days to retain untagged manifests before auto-purge (Premium SKU only). null = manifests kept indefinitely."
  type        = number
  default     = null

  validation {
    condition     = var.retention_policy_in_days == null || (var.retention_policy_in_days >= 1 && var.retention_policy_in_days <= 365)
    error_message = "retention_policy_in_days must be between 1 and 365."
  }
}

variable "trust_policy_enabled" {
  description = "Enable content trust (image signing — Docker Notary v1). Premium SKU only."
  type        = bool
  default     = false
}

###############################################################
# IDENTITY & CUSTOMER-MANAGED KEY (Premium SKU)
###############################################################
variable "identity_ids" {
  description = "List of User-Assigned Identity IDs to attach to the registry. Required when customer_managed_key is set (the MI accesses Key Vault). Empty = no managed identity."
  type        = list(string)
  default     = []
}

variable "customer_managed_key" {
  description = "CMK encryption configuration (Premium SKU only). When set, requires one entry in identity_ids whose client_id matches identity_client_id below."
  type = object({
    key_vault_key_id   = string
    identity_client_id = string
  })
  default = null
}

###############################################################
# DIAGNOSTIC SETTINGS
###############################################################
variable "diagnostic_setting" {
  description = "Optional diagnostic settings emitting to a Log Analytics Workspace. Default categories cover ContainerRegistryRepositoryEvents + ContainerRegistryLoginEvents (audit trail for image pulls/pushes/login attempts)."
  type = object({
    name                       = optional(string, "diag")
    log_analytics_workspace_id = string
    categories                 = optional(list(string), ["ContainerRegistryRepositoryEvents", "ContainerRegistryLoginEvents"])
    metrics_enabled            = optional(bool, true)
  })
  default = null
}

###############################################################
# RBAC & LOCK
###############################################################
variable "role_assignments" {
  description = <<-EOT
  A map of role assignments to create on this ACR. The map key is deliberately
  arbitrary to avoid issues where map keys may be unknown at plan time.

  - `role_definition_id_or_name`             - (Required) The ID or name of the role definition (e.g. "AcrPull", "AcrPush").
  - `principal_id`                           - (Required) The ID of the principal to assign the role to.
  - `principal_type`                         - (Optional) User, Group, or ServicePrincipal.
  - `condition`                              - (Optional) ABAC condition.
  - `condition_version`                      - (Optional) Condition version ("2.0").
  - `description`                            - (Optional) Description.
  - `skip_service_principal_aad_check`       - (Optional) Skip AAD check.
  - `delegated_managed_identity_resource_id` - (Optional) Cross-tenant.
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
}

variable "lock" {
  type = object({
    kind = string
    name = optional(string)
  })
  default     = null
  description = <<-EOT
  Controls the Resource Lock configuration for this resource.

  - `kind` - (Required) "CanNotDelete" or "ReadOnly".
  - `name` - (Optional) Lock name. Generated from kind if not specified.
  EOT

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "Lock kind must be either \"CanNotDelete\" or \"ReadOnly\"."
  }
}

###############################################################
# TAGS
###############################################################
variable "tags" {
  type        = map(string)
  description = "Tags"
  default     = {}
}
