###############################################################
# MODULE: AvdWorkspace - Variables
###############################################################

###############################################################
# NAMING CONVENTION
# Convention: vdws-{subscription_acronym}-{environment}-{region_code}-{workload}
###############################################################
variable "name" {
  type        = string
  default     = null
  description = "Explicit workspace name. If null, computed automatically."
}

variable "subscription_acronym" {
  type        = string
  default     = null
  description = "Subscription acronym"

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
  description = "Workload suffix"
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

###############################################################
# WORKSPACE CONFIGURATION
###############################################################
variable "friendly_name" {
  type        = string
  description = "Display name shown in clients"
  default     = null
}

variable "description" {
  type    = string
  default = null
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Enable public access to the workspace. Set false when using Private Link (feed PE)."
  default     = true
}

###############################################################
# TAGS
###############################################################
variable "tags" {
  type    = map(string)
  default = {}
}
