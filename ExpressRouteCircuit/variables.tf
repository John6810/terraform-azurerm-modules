###############################################################
# MODULE: ExpressRouteCircuit - Variables
###############################################################

###############################################################
# NAMING CONVENTION
# Convention: er-{subscription_acronym}-{environment}-{region_code}-{workload}
# Example:    er-con-prod-gwc-backbone
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
  default     = null
  description = "Workload suffix."

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
  description = "Azure region for the ExpressRoute circuit"
  nullable    = false
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name"
  nullable    = false
}

variable "service_provider_name" {
  type        = string
  description = "ExpressRoute service provider (e.g. DE-CIX, Equinix)"
  nullable    = false
}

variable "peering_location" {
  type        = string
  description = "Peering location (e.g. Frankfurt, Amsterdam)"
  nullable    = false
}

variable "bandwidth_in_mbps" {
  type        = number
  description = "Circuit bandwidth in Mbps"
  nullable    = false
}

###############################################################
# OPTIONAL VARIABLES
###############################################################
variable "sku_tier" {
  type        = string
  default     = "Standard"
  description = "SKU tier (Standard or Premium)"

  validation {
    condition     = contains(["Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be Standard or Premium."
  }
}

variable "sku_family" {
  type        = string
  default     = "MeteredData"
  description = "SKU family (MeteredData or UnlimitedData)"

  validation {
    condition     = contains(["MeteredData", "UnlimitedData"], var.sku_family)
    error_message = "sku_family must be MeteredData or UnlimitedData."
  }
}

variable "allow_classic_operations" {
  type        = bool
  default     = false
  description = "Allow classic operations on the circuit"
}

###############################################################
# AZURE PRIVATE PEERING
# Configure the BGP peering session for VNet/vWAN connectivity.
# Set to null to defer peering configuration (e.g. while waiting
# for the provider to provision the circuit on their side).
###############################################################
variable "private_peering" {
  type = object({
    peer_asn                      = number
    primary_peer_address_prefix   = string
    secondary_peer_address_prefix = string
    vlan_id                       = number
    shared_key                    = optional(string)
    ipv4_enabled                  = optional(bool, true)
  })
  default     = null
  description = <<-EOT
  Azure Private Peering configuration. Set to null to skip peering creation.

  - `peer_asn` — On-premises BGP ASN.
  - `primary_peer_address_prefix` — /30 subnet for the primary BGP session.
  - `secondary_peer_address_prefix` — /30 subnet for the secondary BGP session.
  - `vlan_id` — VLAN tag assigned by the provider.
  - `shared_key` — Optional MD5 BGP authentication key.
  - `ipv4_enabled` — Enable IPv4 family (default true).

  NOTE: AzurePrivatePeering can only be created once the circuit has been
  provisioned by the service provider (serviceProviderProvisioningState =
  "Provisioned"). Apply this module twice if needed:
    1. With private_peering = null  → creates circuit, captures serviceKey
    2. Share serviceKey with provider; wait for provisioning
    3. With private_peering = {...} → adds the peering
  EOT
}

variable "lock" {
  type = object({
    kind = string
    name = optional(string)
  })
  default     = null
  description = "Optional management lock (CanNotDelete or ReadOnly)"

  validation {
    condition     = var.lock == null || contains(["CanNotDelete", "ReadOnly"], try(var.lock.kind, ""))
    error_message = "Lock kind must be CanNotDelete or ReadOnly."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply"
}
