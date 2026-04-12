###############################################################
# MODULE: Vnet - Variables
###############################################################

###############################################################
# NAMING CONVENTION
###############################################################
variable "name" {
  type        = string
  default     = null
  description = "Optional. Explicit VNet name. If null, computed from naming components."
}

variable "subscription_acronym" {
  type        = string
  default     = null
  description = "Subscription acronym for naming convention (e.g. mgm, con, api)"

  validation {
    condition     = var.subscription_acronym == null || can(regex("^[a-z]{2,5}$", var.subscription_acronym))
    error_message = "subscription_acronym must be 2 to 5 lowercase letters."
  }
}

variable "environment" {
  type        = string
  default     = null
  description = "Environment for naming convention (e.g. prod, nprd)"

  validation {
    condition     = var.environment == null || can(regex("^[a-z]{2,4}$", var.environment))
    error_message = "environment must be 2 to 4 lowercase letters."
  }
}

variable "region_code" {
  type        = string
  default     = null
  description = "Region code for naming convention (e.g. gwc, weu)"

  validation {
    condition     = var.region_code == null || can(regex("^[a-z]{2,5}$", var.region_code))
    error_message = "region_code must be 2 to 5 lowercase letters."
  }
}

variable "workload" {
  type        = string
  default     = null
  description = "Workload name for naming convention (e.g. hub, spoke)"

  validation {
    condition     = var.workload == null || can(regex("^[a-z][a-z0-9_-]{1,30}$", var.workload))
    error_message = "workload must be 2 to 31 characters: lowercase letters, digits, hyphens, underscores."
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

variable "resource_group_name" {
  type        = string
  description = "Resource group name"
  nullable    = false
}

###############################################################
# VNET CONFIGURATION
###############################################################
variable "address_space" {
  type        = list(string)
  description = "VNet CIDR address space (e.g. [\"10.238.0.0/22\"])"
  default     = null
  nullable    = true
}

variable "dns_servers" {
  type        = list(string)
  description = "Custom DNS server IPs. If null or empty, uses Azure default DNS."
  default     = null
  nullable    = true
}

variable "enable_ddos_protection" {
  type        = bool
  description = "Enable DDoS Standard protection on the VNet. Requires ddos_protection_plan_id."
  default     = false
}

variable "ddos_protection_plan_id" {
  type        = string
  description = "DDoS Protection Plan ID to associate with the VNet"
  default     = null
}

variable "ip_address_pool" {
  description = "Optional Azure IPAM pool configuration for the VNet"
  type = object({
    id                     = string
    number_of_ip_addresses = string
  })
  default = null
}

###############################################################
# INLINE SUBNETS (optional)
###############################################################
variable "subnets" {
  description = "Optional list of subnets to create within this VNet. When empty, use the separate SubnetWithNsg module."
  type = list(object({
    name                              = string
    address_prefixes                  = optional(list(string))
    nsg_id                            = optional(string)
    service_endpoints                 = optional(list(string))
    route_table_id                    = optional(string)
    nat_gateway_id                    = optional(string)
    ip_address_pool                   = optional(object({ id = string, number_of_ip_addresses = number }))
    private_endpoint_network_policies = optional(string)
    default_outbound_access_enabled   = optional(bool, false)
    delegations = optional(list(object({
      name = string
      service_delegation = object({
        name    = string
        actions = list(string)
      })
    })), [])
  }))
  default = []

  validation {
    condition = alltrue([
      for s in var.subnets :
      s.address_prefixes == null || length(s.address_prefixes) > 0
    ])
    error_message = "address_prefixes must not be an empty list. Either omit it (null) or provide at least one CIDR block."
  }
}

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
  description = "Tags to assign to the VNet"
  default     = {}
}
