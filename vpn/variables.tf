# ═══════════════════════════════════════════════════════════════════════════════
# NAMING CONVENTION
# ═══════════════════════════════════════════════════════════════════════════════

variable "name" {
  description = "Optional. Explicit VPN Gateway name. If null, computed from naming components."
  type        = string
  default     = null
}

variable "subscription_acronym" {
  description = "Subscription acronym for naming convention (e.g. mgm, con, api)"
  type        = string
  default     = null

  validation {
    condition     = var.subscription_acronym == null || can(regex("^[a-z]{2,5}$", var.subscription_acronym))
    error_message = "subscription_acronym must be 2 to 5 lowercase letters."
  }
}

variable "environment" {
  description = "Environment for naming convention (e.g. prod, nprd)"
  type        = string
  default     = null

  validation {
    condition     = var.environment == null || can(regex("^[a-z]{2,4}$", var.environment))
    error_message = "environment must be 2 to 4 lowercase letters."
  }
}

variable "region_code" {
  description = "Region code for naming convention (e.g. gwc, weu)"
  type        = string
  default     = null

  validation {
    condition     = var.region_code == null || can(regex("^[a-z]{2,5}$", var.region_code))
    error_message = "region_code must be 2 to 5 lowercase letters."
  }
}

variable "workload" {
  description = "Workload name for naming convention (e.g. hub, 001)"
  type        = string
  default     = null

  validation {
    condition     = var.workload == null || can(regex("^[a-z][a-z0-9_-]{1,30}$", var.workload))
    error_message = "workload must be 2 to 31 characters: lowercase letters, digits, hyphens, underscores."
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# REQUIRED VARIABLES
# ═══════════════════════════════════════════════════════════════════════════════

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
  nullable    = false
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  nullable    = false
}

variable "subnet_id" {
  description = "ID of the GatewaySubnet where the VPN Gateway will be deployed"
  type        = string
  nullable    = false
}

# ═══════════════════════════════════════════════════════════════════════════════
# OPTIONAL VARIABLES
# ═══════════════════════════════════════════════════════════════════════════════

variable "sku" {
  description = "SKU of the VPN Gateway (Basic, VpnGw1, VpnGw2, VpnGw3, VpnGw1AZ, VpnGw2AZ, VpnGw3AZ)"
  type        = string
  default     = "VpnGw1"
  nullable    = false

  validation {
    condition     = contains(["Basic", "VpnGw1", "VpnGw2", "VpnGw3", "VpnGw4", "VpnGw5", "VpnGw1AZ", "VpnGw2AZ", "VpnGw3AZ", "VpnGw4AZ", "VpnGw5AZ"], var.sku)
    error_message = "SKU must be one of: Basic, VpnGw1, VpnGw2, VpnGw3, VpnGw4, VpnGw5, VpnGw1AZ, VpnGw2AZ, VpnGw3AZ, VpnGw4AZ, VpnGw5AZ"
  }
}

variable "type" {
  description = "Type of VPN Gateway (Vpn or ExpressRoute)"
  type        = string
  default     = "Vpn"
  nullable    = false

  validation {
    condition     = contains(["Vpn", "ExpressRoute"], var.type)
    error_message = "Type must be either 'Vpn' or 'ExpressRoute'"
  }
}

variable "vpn_type" {
  description = "VPN type (RouteBased or PolicyBased)"
  type        = string
  default     = "RouteBased"
  nullable    = false

  validation {
    condition     = contains(["RouteBased", "PolicyBased"], var.vpn_type)
    error_message = "VPN type must be either 'RouteBased' or 'PolicyBased'"
  }
}

variable "generation" {
  description = "Generation of the VPN Gateway (Generation1, Generation2, None)"
  type        = string
  default     = "Generation1"
  nullable    = false

  validation {
    condition     = contains(["Generation1", "Generation2", "None"], var.generation)
    error_message = "Generation must be one of: Generation1, Generation2, None"
  }
}

variable "enable_bgp" {
  description = "Enable BGP for the VPN Gateway"
  type        = bool
  default     = false
  nullable    = false
}

variable "active_active" {
  description = "Enable active-active mode (requires two public IPs)"
  type        = bool
  default     = false
  nullable    = false
}

variable "private_ip_address_allocation" {
  description = "Private IP allocation method for the gateway IP configuration (Dynamic or Static)"
  type        = string
  default     = "Dynamic"
  nullable    = false

  validation {
    condition     = contains(["Dynamic", "Static"], var.private_ip_address_allocation)
    error_message = "IP allocation must be either 'Dynamic' or 'Static'"
  }
}

variable "bgp_settings" {
  description = "BGP settings for the VPN Gateway"
  type = object({
    asn         = optional(number)
    peer_weight = optional(number)
  })
  default = null
}

variable "vpn_client_configuration" {
  description = "VPN client configuration for Point-to-Site VPN"
  type = object({
    address_space        = list(string)
    vpn_client_protocols = optional(list(string), ["OpenVPN", "IkeV2"])
    aad_tenant           = optional(string)
    aad_audience         = optional(string)
    aad_issuer           = optional(string)
    root_certificate = optional(list(object({
      name             = string
      public_cert_data = string
    })), [])
    revoked_certificate = optional(list(object({
      name       = string
      thumbprint = string
    })), [])
  })
  default = null
}

variable "local_network_gateways" {
  description = "Map of local network gateways and site-to-site connections to create"
  type = map(object({
    gateway_address = string
    address_space   = list(string)
    bgp_settings = optional(object({
      asn                 = number
      bgp_peering_address = string
      peer_weight         = optional(number, 0)
    }))
    shared_key                         = string
    connection_mode                    = optional(string, "Default")
    connection_protocol                = optional(string, "IKEv2")
    enable_bgp                         = optional(bool, false)
    custom_bgp_addresses               = optional(list(string), [])
    dpd_timeout_seconds                = optional(number, 45)
    use_policy_based_traffic_selectors = optional(bool, false)
  }))
  default   = {}
  sensitive = true
}

# ═══════════════════════════════════════════════════════════════════════════════
# LOCK
# ═══════════════════════════════════════════════════════════════════════════════

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

# ═══════════════════════════════════════════════════════════════════════════════
# TAGS
# ═══════════════════════════════════════════════════════════════════════════════

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
