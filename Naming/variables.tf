###############################################################
# MODULE: Naming - Variables
# Wraps Azure/naming/azurerm + custom naming for resources
# not covered by the official module (Palo Alto, etc.)
###############################################################

variable "prefix" {
  type        = list(string)
  description = "Prefix to add to all resource names (e.g. [\"neko\"])"
  default     = []

  validation {
    condition     = alltrue([for p in var.prefix : length(p) <= 10])
    error_message = "Each prefix element must not exceed 10 characters."
  }

  validation {
    condition     = alltrue([for p in var.prefix : can(regex("^[a-zA-Z0-9-]+$", p))])
    error_message = "Each prefix element must contain only alphanumeric characters and hyphens."
  }
}

variable "suffix" {
  type        = list(string)
  description = "Suffix to add to all resource names (e.g. [\"01\"])"
  default     = []

  validation {
    condition     = alltrue([for s in var.suffix : length(s) <= 10])
    error_message = "Each suffix element must not exceed 10 characters."
  }

  validation {
    condition     = alltrue([for s in var.suffix : can(regex("^[a-zA-Z0-9-]+$", s))])
    error_message = "Each suffix element must contain only alphanumeric characters and hyphens."
  }
}

variable "environment" {
  type        = string
  description = "Environment short name (e.g. prod, nprd, dev, test, dr, lab). 2-4 lowercase letters — same shape used by every other module in this repo."
  default     = null

  validation {
    condition     = var.environment == null || can(regex("^[a-z]{2,4}$", var.environment))
    error_message = "environment must be 2 to 4 lowercase letters (e.g. prod, nprd, dev, test, dr, lab)."
  }
}

variable "region" {
  type        = string
  description = "Azure region short name (e.g. weu, gwc, eus)"
  default     = null

  validation {
    condition     = var.region == null || can(regex("^[a-z]{2,5}$", var.region))
    error_message = "Region must be 2-5 lowercase letters."
  }
}

variable "workload" {
  type        = string
  description = <<-EOT
  Workload identifier (e.g. "obew", "aks", "apim"). When set, inserted
  into the custom names template between the resource short_name and
  the environment to avoid cross-workload name collisions on shared
  scopes — notably required for Palo Alto custom roles assigned at
  subscription/MG scope where the role name must be globally unique
  across env+workload (CLAUDE.md gotcha #8).
  EOT
  default     = null

  validation {
    condition     = var.workload == null || can(regex("^[a-z0-9][a-z0-9-]{0,30}$", var.workload))
    error_message = "workload must be 1 to 31 characters: lowercase letters, digits, hyphens."
  }
}

variable "unique_seed" {
  type        = string
  description = "Seed for generating unique names (passed to Azure naming module)"
  default     = ""
}

variable "unique_length" {
  type        = number
  description = "Length of unique suffix for resource names (1-8)"
  default     = 4

  validation {
    condition     = var.unique_length >= 1 && var.unique_length <= 8
    error_message = "unique_length must be between 1 and 8."
  }
}

variable "custom_resource_types" {
  type        = map(string)
  description = "Additional custom resource types to support. Key = type name, value = short name."
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.custom_resource_types :
      length(v) >= 2 && length(v) <= 10
    ])
    error_message = "Custom resource type short names must be between 2 and 10 characters."
  }
}

variable "name_suffixes" {
  type        = list(string)
  description = "Name suffixes for building multiple resource name variations (e.g. [\"trust\", \"untrust\", \"mgmt\"])"
  default     = []
}
