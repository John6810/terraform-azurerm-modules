###############################################################
# MODULE: PrivateDnsZonesCorp - Variables
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

variable "location" {
  type        = string
  description = "Azure region"
  nullable    = false
}

variable "zones" {
  type        = set(string)
  description = "Set of corporate private DNS zone names to host on Azure (e.g. [\"az.epttst.lu\"])."
  default     = []
  nullable    = false

  validation {
    condition = alltrue([
      for z in var.zones :
      can(regex("^([a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", z))
    ])
    error_message = "Each zone must be a lowercase FQDN (e.g. \"az.epttst.lu\"). Labels must be 1-63 chars, start/end with alphanumeric, and may contain hyphens; the TLD is 2-63 letters. Trailing dots are not allowed."
  }
}

variable "virtual_network_links" {
  type = map(object({
    virtual_network_resource_id = string
    registration_enabled        = optional(bool, false)
  }))
  description = "Map of logical name => VNet link config. Each VNet is linked to every zone."
  default     = {}
  nullable    = false
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply"
}
