###############################################################
# MODULE: AvdHostPool - Variables
###############################################################

###############################################################
# NAMING CONVENTION
# Convention: vdpool-{subscription_acronym}-{environment}-{region_code}-{workload}
###############################################################
variable "name" {
  type        = string
  default     = null
  description = "Explicit host pool name. If null, computed automatically."
}

variable "subscription_acronym" {
  type        = string
  default     = null
  description = "Subscription acronym (e.g. avd, api)"

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
  description = "Workload suffix (e.g. pooled, personal)"
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
# HOST POOL CONFIGURATION
###############################################################
variable "type" {
  type        = string
  description = "Host pool type: Pooled or Personal"
  default     = "Pooled"

  validation {
    condition     = contains(["Pooled", "Personal"], var.type)
    error_message = "type must be 'Pooled' or 'Personal'."
  }
}

variable "load_balancer_type" {
  type        = string
  description = "Load balancer algorithm: BreadthFirst, DepthFirst, or Persistent (Personal only)"
  default     = "BreadthFirst"

  validation {
    condition     = contains(["BreadthFirst", "DepthFirst", "Persistent"], var.load_balancer_type)
    error_message = "load_balancer_type must be 'BreadthFirst', 'DepthFirst', or 'Persistent'."
  }
}

variable "maximum_sessions_allowed" {
  type        = number
  description = "Max concurrent sessions per session host (Pooled only). MS recommends 8-16 for Win11 multi-session."
  default     = 8
}

variable "preferred_app_group_type" {
  type        = string
  description = "Preferred app group type: Desktop or RailApplications"
  default     = "Desktop"

  validation {
    condition     = contains(["Desktop", "RailApplications"], var.preferred_app_group_type)
    error_message = "preferred_app_group_type must be 'Desktop' or 'RailApplications'."
  }
}

variable "start_vm_on_connect" {
  type        = bool
  description = "Wake session hosts from deallocated state on incoming connection (pairs with Autoscale)"
  default     = true
}

variable "validate_environment" {
  type        = bool
  description = "Mark as validation environment (receives AVD agent updates first)"
  default     = false
}

variable "friendly_name" {
  type        = string
  description = "Display name shown in clients"
  default     = null
}

variable "description" {
  type        = string
  default     = null
}

variable "custom_rdp_properties" {
  type        = string
  description = "Semicolon-separated RDP properties (e.g. \"audiocapturemode:i:1;camerastoredirect:s:*\")"
  default     = null
}

###############################################################
# TAGS
###############################################################
variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags"
}
