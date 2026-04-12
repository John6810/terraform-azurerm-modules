###############################################################
# MODULE: ActionGroup - Variables
###############################################################

###############################################################
# NAMING CONVENTION
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
  default     = "ama"
  description = "Workload name (e.g. ama)"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_-]{0,30}$", var.workload))
    error_message = "workload must be 1 to 31 characters: lowercase letters, digits, hyphens, underscores."
  }
}

###############################################################
# REQUIRED VARIABLES
###############################################################
variable "resource_group_name" {
  type        = string
  description = "Resource group name"
  nullable    = false
}

###############################################################
# ACTION GROUP CONFIGURATION
###############################################################
variable "short_name" {
  type        = string
  default     = "ldz-ama"
  description = "Short name for the action group (max 12 chars)"

  validation {
    condition     = length(var.short_name) >= 1 && length(var.short_name) <= 12
    error_message = "short_name must be between 1 and 12 characters."
  }
}

variable "email_addresses" {
  type        = list(string)
  default     = []
  sensitive   = true
  description = "List of email addresses for alert email receivers"
}

variable "push_email_addresses" {
  type        = list(string)
  default     = []
  sensitive   = true
  description = "List of email addresses for Azure App push receivers"
}

###############################################################
# TAGS
###############################################################
variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply"
}
