###############################################################
# MODULE: DnsResolver - Variables
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
  description = "Subscription acronym (e.g. con)"

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

###############################################################
# REQUIRED VARIABLES
###############################################################
variable "location" {
  type        = string
  description = "Azure region"
  nullable    = false
}

variable "virtual_network_id" {
  type        = string
  description = "VNet ID in which to deploy the resolver"
  nullable    = false

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+$", var.virtual_network_id))
    error_message = "virtual_network_id must be a valid Azure VNet resource ID."
  }
}

variable "inbound_subnet_id" {
  type        = string
  description = "Subnet ID for the inbound endpoint (Microsoft.Network/dnsResolvers delegation required)"
  nullable    = false

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.inbound_subnet_id))
    error_message = "inbound_subnet_id must be a valid Azure Subnet resource ID."
  }
}

###############################################################
# OPTIONAL VARIABLES
###############################################################
variable "inbound_private_ip" {
  type        = string
  default     = null
  description = "Static private IP for the inbound endpoint. If null, dynamic allocation."

  validation {
    condition     = var.inbound_private_ip == null || can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$", var.inbound_private_ip))
    error_message = "inbound_private_ip must be a valid IPv4 address."
  }
}

variable "outbound_subnet_id" {
  type        = string
  default     = null
  description = "Subnet ID for the outbound endpoint. If null, no outbound endpoint is created."

  validation {
    condition     = var.outbound_subnet_id == null || can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.outbound_subnet_id))
    error_message = "outbound_subnet_id must be a valid Azure Subnet resource ID."
  }
}

variable "forwarding_rules" {
  description = <<-EOT
  Map of DNS forwarding rules. Key = rule name.
  Requires outbound_subnet_id to be set.

  - `domain_name`        - (Required) FQDN to forward (must end with ".").
  - `target_dns_servers`  - (Required) List of target DNS servers.
  - `enabled`             - (Optional) Enable the rule. Defaults to true.
  EOT
  type = map(object({
    domain_name = string
    target_dns_servers = list(object({
      ip_address = string
      port       = optional(number, 53)
    }))
    enabled = optional(bool, true)
  }))
  default  = {}
  nullable = false
}

variable "ruleset_vnet_links" {
  type        = map(string)
  default     = {}
  nullable    = false
  description = "Map of name => VNet ID to link to the forwarding ruleset."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply"
}
