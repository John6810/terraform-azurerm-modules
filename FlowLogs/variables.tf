###############################################################
# MODULE: FlowLogs - Variables
# VNet Flow Logs with optional Traffic Analytics
###############################################################

###############################################################
# NAMING CONVENTION
###############################################################
variable "subscription_acronym" {
  type        = string
  description = "Subscription acronym (e.g. con, mgm, api)"

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

variable "network_watcher_name" {
  type        = string
  description = "Name of the Network Watcher to host the flow log resources"
  nullable    = false
}

variable "network_watcher_resource_group_name" {
  type        = string
  description = "Resource group of the Network Watcher"
  nullable    = false
}

variable "storage_account_id" {
  type        = string
  description = "Storage Account resource ID for flow log data"
  nullable    = false

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Storage/storageAccounts/[^/]+$", var.storage_account_id))
    error_message = "storage_account_id must be a valid Azure Storage Account resource ID."
  }
}

variable "vnets" {
  type = map(object({
    id      = string
    enabled = optional(bool, true)
  }))
  description = "Map of VNets to enable flow logs on. Key = short name used in the flow log resource name."
  nullable    = false
}

###############################################################
# OPTIONAL VARIABLES
###############################################################
variable "retention_days" {
  type        = number
  default     = 90
  description = "Number of days to retain flow logs in the storage account (0 = forever)"

  validation {
    condition     = var.retention_days >= 0 && var.retention_days <= 365
    error_message = "retention_days must be between 0 and 365."
  }
}

variable "traffic_analytics" {
  type = object({
    enabled             = optional(bool, true)
    workspace_id        = string
    workspace_region    = string
    workspace_resource_id = string
    interval_minutes    = optional(number, 60)
  })
  default     = null
  description = "Traffic Analytics configuration. Set to null to disable."

  validation {
    condition     = var.traffic_analytics == null || contains([10, 60], try(var.traffic_analytics.interval_minutes, 60))
    error_message = "traffic_analytics.interval_minutes must be 10 or 60."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply"
}
