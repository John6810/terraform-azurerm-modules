###############################################################
# NAMING CONVENTION
# Convention: hsm-{subscription_acronym}-{environment}-{region_code}-{workload}
# Example:    hsm-mgm-nprd-gwc-01
###############################################################
variable "name" {
  type        = string
  default     = null
  description = "Optional. Explicit name. If null, computed from naming components."
}

variable "subscription_acronym" {
  type        = string
  default     = null
  description = "Subscription acronym (e.g. mgm, con)"

  validation {
    condition     = var.subscription_acronym == null || can(regex("^[a-z]{2,5}$", var.subscription_acronym))
    error_message = "subscription_acronym must be 2-5 lowercase letters."
  }
}

variable "environment" {
  type        = string
  default     = null
  description = "Environment (e.g. prod, nprd)"

  validation {
    condition     = var.environment == null || can(regex("^[a-z]{2,4}$", var.environment))
    error_message = "environment must be 2-4 lowercase letters."
  }
}

variable "region_code" {
  type        = string
  default     = null
  description = "Region code (e.g. gwc, weu)"

  validation {
    condition     = var.region_code == null || can(regex("^[a-z]{2,5}$", var.region_code))
    error_message = "region_code must be 2-5 lowercase letters."
  }
}

variable "workload" {
  type        = string
  default     = "01"
  description = "Workload suffix"

  validation {
    condition     = var.workload == null || can(regex("^[a-z0-9][a-z0-9_-]{0,30}$", var.workload))
    error_message = "workload must start with a lowercase letter or digit and contain only lowercase letters, digits, hyphens, or underscores (max 31 chars)."
  }
}

variable "location" {
  type        = string
  nullable    = false
  description = "Azure region"
}

variable "resource_group_name" {
  type        = string
  default     = null
  description = "Resource group name. Required when create_resource_group = false."
}

variable "create_resource_group" {
  type        = bool
  default     = false
  description = "If true, creates the resource group inline."
}

variable "resource_group_workload" {
  type        = string
  default     = "hsm"
  description = "Workload name for RG naming convention when create_resource_group = true."
}

variable "sku_name" {
  type        = string
  default     = "Standard_B1"
  description = "SKU of the Managed HSM"
}

variable "purge_protection_enabled" {
  type        = bool
  default     = true
  description = "Enable purge protection"
}

variable "soft_delete_retention_days" {
  type        = number
  default     = 90
  description = "Soft delete retention in days"
}

variable "admin_object_ids" {
  type        = list(string)
  default     = []
  description = "Admin object IDs. Defaults to current user."
}

variable "public_network_access_enabled" {
  type        = bool
  default     = false
  description = "Enable public network access. HSM should use Private Endpoints in production."
}

###############################################################
# PRIVATE ENDPOINT
###############################################################
variable "private_endpoint_subnet_id" {
  type        = string
  default     = null
  description = "Subnet ID for the Private Endpoint. If set, a PE is created and public access is disabled."
}

variable "private_dns_zone_ids" {
  type        = list(string)
  default     = []
  description = "Private DNS Zone IDs for the PE DNS zone group (privatelink.managedhsm.azure.net)."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply"
}
