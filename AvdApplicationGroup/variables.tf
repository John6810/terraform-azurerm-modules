###############################################################
# MODULE: AvdApplicationGroup - Variables
###############################################################

###############################################################
# NAMING CONVENTION
# Convention: vdag-{subscription_acronym}-{environment}-{region_code}-{workload}
###############################################################
variable "name" {
  type        = string
  default     = null
  description = "Explicit app group name. If null, computed automatically."
}

variable "subscription_acronym" {
  type        = string
  default     = null

  validation {
    condition     = var.subscription_acronym == null || can(regex("^[a-z]{2,5}$", var.subscription_acronym))
    error_message = "subscription_acronym must be 2 to 5 lowercase letters."
  }
}

variable "environment" {
  type        = string
  default     = null

  validation {
    condition     = var.environment == null || can(regex("^[a-z]{2,4}$", var.environment))
    error_message = "environment must be 2 to 4 lowercase letters."
  }
}

variable "region_code" {
  type        = string
  default     = null

  validation {
    condition     = var.region_code == null || can(regex("^[a-z]{2,5}$", var.region_code))
    error_message = "region_code must be 2 to 5 lowercase letters."
  }
}

variable "workload" {
  type        = string
  default     = null
  description = "Workload suffix (e.g. desktop, remoteapp)"
}

###############################################################
# REQUIRED VARIABLES
###############################################################
variable "location" {
  type     = string
  nullable = false
}

variable "resource_group_name" {
  type     = string
  nullable = false
}

variable "host_pool_id" {
  type        = string
  description = "Host pool resource ID to bind this app group to"
  nullable    = false
}

###############################################################
# APP GROUP CONFIGURATION
###############################################################
variable "type" {
  type        = string
  description = "Application group type: Desktop or RemoteApp"
  default     = "Desktop"

  validation {
    condition     = contains(["Desktop", "RemoteApp"], var.type)
    error_message = "type must be 'Desktop' or 'RemoteApp'."
  }
}

variable "friendly_name" {
  type    = string
  default = null
}

variable "description" {
  type    = string
  default = null
}

###############################################################
# WORKSPACE ASSOCIATION (optional)
###############################################################
variable "workspace_id" {
  type        = string
  description = "If set, creates a workspace <-> application group association"
  default     = null
}

###############################################################
# TAGS
###############################################################
variable "tags" {
  type    = map(string)
  default = {}
}
