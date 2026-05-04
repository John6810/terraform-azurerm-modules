###############################################################
# MODULE: NatGateway - Variables
###############################################################

###############################################################
# NAMING CONVENTION
###############################################################
variable "name" {
  type        = string
  default     = null
  description = "Optional. Explicit NAT Gateway name. If null, computed from naming components."
}

variable "subscription_acronym" {
  type        = string
  default     = null
  description = "Subscription acronym (e.g. con, mgm)"

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
  description = "Workload name (e.g. untrust)"

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

variable "resource_group_id" {
  type        = string
  description = "Resource group ID (azapi parent_id)"
  nullable    = false

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+$", var.resource_group_id))
    error_message = "resource_group_id must be a valid Azure Resource Group ID."
  }
}

###############################################################
# OPTIONAL VARIABLES
###############################################################
variable "idle_timeout_in_minutes" {
  type        = number
  default     = 4
  description = "Idle timeout in minutes (4-120)"

  validation {
    condition     = var.idle_timeout_in_minutes >= 4 && var.idle_timeout_in_minutes <= 120
    error_message = "idle_timeout_in_minutes must be between 4 and 120."
  }
}

variable "zones" {
  type        = list(string)
  default     = ["1", "2", "3"]
  description = "Availability zones for the NAT Gateway and Public IP (zone-redundant with StandardV2 SKU)."
}

variable "additional_public_ips" {
  description = <<-EOT
  Optional additional public IPs to attach to the NAT Gateway. The base
  PIP (pip-<name>) is always created; entries here add pip-<name>-<key>
  alongside. Map key becomes the suffix (e.g. "02" → pip-<name>-02).
  Azure caps a NAT Gateway at 16 attached public IPs total — this map is
  capped at 15 (16 total including the base PIP).

  - `zones` - (Optional) Per-PIP zones override. Defaults to var.zones.
  EOT
  type = map(object({
    zones = optional(list(string))
  }))
  default  = {}
  nullable = false

  validation {
    condition     = length(var.additional_public_ips) <= 15
    error_message = "additional_public_ips is limited to 15 entries (16 total including the base PIP — Azure NAT Gateway hard limit)."
  }
}

variable "lock" {
  type = object({
    kind = string
    name = optional(string)
  })
  default     = null
  description = <<-EOT
  Optional management lock on the NAT Gateway. Destroying a NAT Gateway
  breaks egress on every subnet associated with it — set kind =
  "CanNotDelete" in production to require an explicit unlock before
  teardown.

  - `kind` - (Required) "CanNotDelete" or "ReadOnly".
  - `name` - (Optional) Lock name. Defaults to "lock-<kind>".
  EOT

  validation {
    condition     = var.lock == null || contains(["CanNotDelete", "ReadOnly"], try(var.lock.kind, ""))
    error_message = "Lock kind must be either \"CanNotDelete\" or \"ReadOnly\"."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags to assign"
  default     = {}
}
