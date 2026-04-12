###############################################################
# MODULE: PrivateDnsZones - Variables
###############################################################

###############################################################
# NAMING CONVENTION
###############################################################
variable "subscription_acronym" {
  type        = string
  description = "Subscription acronym (e.g. con)"

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

###############################################################
# REQUIRED VARIABLES
###############################################################
variable "location" {
  type        = string
  description = "Azure region"
  nullable    = false
}

###############################################################
# OPTIONAL VARIABLES
###############################################################
variable "virtual_network_links" {
  type = map(object({
    virtual_network_resource_id = string
  }))
  default     = {}
  nullable    = false
  description = "VNets to link to all DNS zones. Key = logical name, value = VNet resource ID."
}

variable "tags" {
  type        = map(string)
  description = "Tags"
  default     = {}
}
