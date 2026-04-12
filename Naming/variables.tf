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
  description = "Environment name (dev, test, nprd, prod, dr, sandbox, lab)"
  default     = null

  validation {
    condition     = var.environment == null || contains(["dev", "test", "nprd", "prod", "dr", "sandbox", "lab"], var.environment)
    error_message = "Environment must be one of: dev, test, nprd, prod, dr, sandbox, lab."
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
