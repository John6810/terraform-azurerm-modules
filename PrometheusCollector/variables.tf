###############################################################
# MODULE: PrometheusCollector - Variables
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
  default     = "prometheus"
  description = "Workload suffix (e.g. prometheus)"

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
  description = "Resource group for the Data Collection Rule"
  nullable    = false
}

variable "aks_cluster_id" {
  type        = string
  description = "ID of the AKS cluster to collect Prometheus metrics from"
  nullable    = false

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.ContainerService/managedClusters/[^/]+$", var.aks_cluster_id))
    error_message = "aks_cluster_id must be a valid Azure AKS cluster resource ID."
  }
}

variable "aks_cluster_name" {
  type        = string
  description = "Name of the AKS cluster (used in recording rule group names)"
  nullable    = false
}

variable "monitor_workspace_id" {
  type        = string
  description = "ID of the Azure Monitor Workspace (Prometheus destination)"
  nullable    = false

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Monitor/accounts/[^/]+$", var.monitor_workspace_id))
    error_message = "monitor_workspace_id must be a valid Azure Monitor Workspace resource ID."
  }
}

variable "data_collection_endpoint_id" {
  type        = string
  description = "ID of the Data Collection Endpoint (from AMW default_data_collection_endpoint_id)"
  nullable    = false
}

###############################################################
# OPTIONAL VARIABLES
###############################################################
variable "enable_recording_rules" {
  type        = bool
  default     = true
  description = "Enable recommended Prometheus recording rules for Kubernetes"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply"
}
