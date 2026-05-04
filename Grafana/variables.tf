###############################################################
# MODULE: Grafana - Variables
###############################################################

###############################################################
# NAMING CONVENTION
###############################################################
variable "subscription_acronym" {
  type        = string
  description = "Subscription acronym (e.g. mgm, con)"

  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.subscription_acronym))
    error_message = "subscription_acronym must be 2 to 5 lowercase letters."
  }
}

variable "environment" {
  type        = string
  description = "Environment (e.g. prod, nprd)"

  validation {
    condition     = can(regex("^[a-z]{2,4}$", var.environment))
    error_message = "environment must be 2 to 4 lowercase letters."
  }
}

variable "region_code" {
  type        = string
  description = "Region code (e.g. gwc, weu)"

  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.region_code))
    error_message = "region_code must be 2 to 5 lowercase letters."
  }
}

variable "location" {
  type        = string
  description = "Azure region"
  nullable    = false
}

###############################################################
# GRAFANA CONFIGURATION
###############################################################
variable "grafana_sku" {
  type        = string
  description = "Grafana instance SKU (Standard or Essential)"
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Essential"], var.grafana_sku)
    error_message = "grafana_sku must be Standard or Essential."
  }
}

variable "grafana_major_version" {
  type        = string
  description = "Grafana major version"
  default     = "11"
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Enable public network access to Grafana. Set to false and use Private Endpoints in production."
  default     = false
}

variable "zone_redundancy_enabled" {
  type        = bool
  description = "Enable zone redundancy (recommended for production)"
  default     = true
}

variable "api_key_enabled" {
  type        = bool
  description = "Enable Grafana API keys"
  default     = false
}

variable "deterministic_outbound_ip_enabled" {
  type        = bool
  description = "Enable deterministic outbound IPs"
  default     = true
}

###############################################################
# AZURE MONITOR INTEGRATION
###############################################################
variable "azure_monitor_workspace_ids" {
  type        = list(string)
  description = "List of Azure Monitor Workspace IDs to integrate"
  default     = []
}

###############################################################
# IDENTITY ROLE ASSIGNMENTS
###############################################################
variable "identity_role_assignments" {
  description = <<-EOT
  A map of role assignments for the Grafana managed identity. The map key is
  deliberately arbitrary to avoid issues where map keys may be unknown at plan time.

  Canonical shape B (scope-based, MI is the principal — see CONTRIBUTING.md
  for the full convention).

  - `role_definition_id_or_name`             - (Required) Role definition ID or name.
  - `scope`                                  - (Required) Azure resource/MG scope.
  - `condition`                              - (Optional) ABAC condition for the role assignment.
  - `condition_version`                      - (Optional) Condition version. Valid values: "2.0".
  - `description`                            - (Optional) Description of the role assignment.
  - `skip_service_principal_aad_check`       - (Optional) Skip AAD check. Default false.
  - `delegated_managed_identity_resource_id` - (Optional) Delegated managed identity for cross-tenant scenarios.
  EOT
  type = map(object({
    role_definition_id_or_name             = string
    scope                                  = string
    condition                              = optional(string)
    condition_version                      = optional(string)
    description                            = optional(string)
    skip_service_principal_aad_check       = optional(bool, false)
    delegated_managed_identity_resource_id = optional(string)
  }))
  default  = {}
  nullable = false
}

###############################################################
# GRAFANA RBAC (Entra ID Groups)
###############################################################
variable "grafana_admin_group_object_ids" {
  type        = list(string)
  description = "Object IDs of Entra ID groups to assign as Grafana Admin"
  default     = []
}

variable "grafana_editor_group_object_ids" {
  type        = list(string)
  description = "Object IDs of Entra ID groups to assign as Grafana Editor"
  default     = []
}

variable "grafana_viewer_group_object_ids" {
  type        = list(string)
  description = "Object IDs of Entra ID groups to assign as Grafana Viewer"
  default     = []
}

###############################################################
# TAGS
###############################################################
###############################################################
# LOCK
###############################################################
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
  description = "Tags to apply to resources"
  default     = {}
}
