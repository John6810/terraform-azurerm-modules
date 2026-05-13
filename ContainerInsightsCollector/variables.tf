###############################################################
# MODULE: ContainerInsightsCollector - Variables
#
# Deploys an explicit DCR + DCRA pair that route Container Insights
# streams (ContainerLogV2, KubeEvents, KubePodInventory, etc.) from
# an AKS cluster to a Log Analytics Workspace. Companion to the
# `oms_agent` addon enabled on the cluster — the addon installs the
# ama-logs DaemonSet, this DCR tells it where + what to ship.
#
# Modern MS-recommended pattern (kubernetes-monitoring-enable.md,
# Terraform tab, updated 2026-04-17): the addon auto-creates a default
# DCR, but callers typically deploy this explicit one to:
#   - opt into ContainerLogV2 only (drop deprecated ContainerLog V1)
#   - skip Microsoft-Perf (redundant with Managed Prometheus)
#   - apply namespace filtering / data collection settings
#   - control stream selection precisely
###############################################################

###############################################################
# NAMING
###############################################################
variable "subscription_acronym" {
  type        = string
  description = "Subscription acronym (e.g. shc, api, mgm)."

  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.subscription_acronym))
    error_message = "subscription_acronym must be 2 to 5 lowercase letters."
  }
}

variable "environment" {
  type        = string
  description = "Environment (e.g. prod, nprd)."

  validation {
    condition     = can(regex("^[a-z]{2,4}$", var.environment))
    error_message = "environment must be 2 to 4 lowercase letters."
  }
}

variable "region_code" {
  type        = string
  description = "Region code (e.g. gwc, weu)."

  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.region_code))
    error_message = "region_code must be 2 to 5 lowercase letters."
  }
}

variable "workload" {
  type        = string
  default     = "containerinsights"
  description = "Workload suffix in the DCR/DCRA names."

  validation {
    condition     = can(regex("^[a-z][a-z0-9_-]{0,30}$", var.workload))
    error_message = "workload must be 1 to 31 characters: lowercase letters, digits, hyphens, underscores."
  }
}

###############################################################
# REQUIRED
###############################################################
variable "location" {
  type        = string
  description = "Azure region for the DCR (must match the AKS cluster's region)."
  nullable    = false
}

variable "resource_group_name" {
  type        = string
  description = "Resource group where the DCR is deployed (typically the AKS cluster RG)."
  nullable    = false
}

variable "aks_cluster_id" {
  type        = string
  description = "Full resource ID of the AKS cluster to associate the DCR with."
  nullable    = false

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.ContainerService/managedClusters/[^/]+$", var.aks_cluster_id))
    error_message = "aks_cluster_id must be a valid AKS resource ID."
  }
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Full resource ID of the Log Analytics Workspace receiving Container Insights data."
  nullable    = false

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.OperationalInsights/workspaces/[^/]+$", var.log_analytics_workspace_id))
    error_message = "log_analytics_workspace_id must be a valid LAW resource ID."
  }
}

###############################################################
# OPTIONAL
###############################################################
variable "streams" {
  type        = list(string)
  description = <<-EOT
  Streams to collect. Defaults to the modern Container Insights set
  (ContainerLogV2 for stdout/stderr, KubeEvents, KubePodInventory,
  KubeNodeInventory, KubeServices, KubePVInventory, KubeMonAgentEvents,
  ContainerNodeInventory, ContainerInventory, InsightsMetrics).

  Skipped on purpose vs the addon defaults:
    - Microsoft-ContainerLog (V1, deprecated — use V2)
    - Microsoft-Perf (redundant with Managed Prometheus)
  EOT
  default = [
    "Microsoft-ContainerLogV2",
    "Microsoft-KubeEvents",
    "Microsoft-KubePodInventory",
    "Microsoft-KubeNodeInventory",
    "Microsoft-KubeServices",
    "Microsoft-KubePVInventory",
    "Microsoft-KubeMonAgentEvents",
    "Microsoft-ContainerNodeInventory",
    "Microsoft-ContainerInventory",
    "Microsoft-InsightsMetrics",
  ]
}

variable "data_collection_settings" {
  type = object({
    interval               = optional(string, "1m")
    namespace_filter_mode  = optional(string, "Off")
    namespaces             = optional(list(string), [])
    enable_container_log_v2 = optional(bool, true)
  })
  description = <<-EOT
  Container Insights agent settings (passed as extension_json to the
  ContainerInsights data source extension).

  - interval: scrape interval, ISO 8601-ish (e.g. "1m", "30s").
  - namespace_filter_mode: "Off" (collect all), "Include", or "Exclude".
  - namespaces: list of k8s namespaces matching the filter mode.
  - enable_container_log_v2: emit ContainerLogV2 (modern) when true.
  EOT
  default = {}
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to the DCR."
}
