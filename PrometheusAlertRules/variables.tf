###############################################################
# MODULE: PrometheusAlertRules - Variables
###############################################################

###############################################################
# NAMING CONVENTION
###############################################################
variable "subscription_acronym" {
  type        = string
  description = "Subscription acronym (e.g. api, mgm)"

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

variable "workload" {
  type        = string
  default     = "aks-alerts"
  description = "Workload suffix"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_-]{0,30}$", var.workload))
    error_message = "workload must be 1 to 31 characters: lowercase letters, digits, hyphens, underscores."
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
  description = "Resource group for the alert rule groups"
  nullable    = false
}

variable "aks_cluster_id" {
  type        = string
  description = "ID of the AKS cluster"
  nullable    = false

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.ContainerService/managedClusters/[^/]+$", var.aks_cluster_id))
    error_message = "aks_cluster_id must be a valid Azure AKS cluster resource ID."
  }
}

variable "aks_cluster_name" {
  type        = string
  description = "Name of the AKS cluster (used in alert rule group names)"
  nullable    = false
}

variable "monitor_workspace_id" {
  type        = string
  description = "ID of the Azure Monitor Workspace (Prometheus scope)"
  nullable    = false

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Monitor/accounts/[^/]+$", var.monitor_workspace_id))
    error_message = "monitor_workspace_id must be a valid Azure Monitor Workspace resource ID."
  }
}

variable "action_group_id" {
  type        = string
  description = "Single Action Group ID for alert notifications. Concatenated with action_group_ids; combined list is capped at 5 (Azure limit)."
  nullable    = false
}

variable "action_group_ids" {
  type        = list(string)
  description = "Additional Action Group IDs for alert notifications. Combined with action_group_id; final list capped at 5 (Azure limit)."
  default     = []

  validation {
    condition     = length(var.action_group_ids) <= 5
    error_message = "action_group_ids list cannot exceed 5 entries (Azure limit per alert rule)."
  }
}

###############################################################
# RULE GROUPS
###############################################################
variable "rule_groups" {
  type = map(object({
    interval = optional(string, "PT1M")
    enabled  = optional(bool, true)
    alerts = map(object({
      expression  = string
      for         = optional(string, "PT15M")
      severity    = optional(number, 3)
      enabled     = optional(bool, true)
      labels      = optional(map(string), {})
      annotations = optional(map(string), {})
    }))
  }))
  description = "Map of Prometheus alert rule groups. Key = group name suffix. Max 20 rules per group (Azure limit). severity must be 0..4."
  nullable    = false

  validation {
    condition     = alltrue([for g in var.rule_groups : length(g.alerts) <= 20])
    error_message = "Each alert rule group is limited to 20 alerts (Azure hard limit on azurerm_monitor_alert_prometheus_rule_group). Split into multiple groups if you have more."
  }

  validation {
    condition = alltrue([
      for g in var.rule_groups : alltrue([
        for a in g.alerts : a.severity >= 0 && a.severity <= 4
      ])
    ])
    error_message = "Each alert severity must be in [0..4] (0=critical, 4=verbose)."
  }
}

###############################################################
# OPTIONAL VARIABLES
###############################################################
variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply"
}
