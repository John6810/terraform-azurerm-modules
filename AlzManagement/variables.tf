###############################################################
# NAMING CONVENTION
# LAW:        law-{sub}-{env}-{region}-{workload}
# Automation: aa-{sub}-{env}-{region}-{workload}
# Identity:   id-{sub}-{env}-{region}-{law|ama}
###############################################################
variable "subscription_acronym" {
  type        = string
  description = "Subscription acronym (e.g. mgm, con)"
  nullable    = false
}

variable "environment" {
  type        = string
  description = "Environment (e.g. prod, nprd)"
  nullable    = false
}

variable "region_code" {
  type        = string
  description = "Region code (e.g. gwc, weu)"
  nullable    = false
}

variable "workload" {
  type        = string
  default     = "01"
  description = "Workload suffix for naming"
}

variable "location" {
  type        = string
  description = "Azure region"
  nullable    = false
}

variable "resource_group_name" {
  type        = string
  default     = null
  description = "Resource group name. Required when create_resource_group = false."
}

variable "create_resource_group" {
  type        = bool
  default     = false
  description = "If true, creates the resource group inline. If false, resource_group_name must reference an existing RG."
}

variable "resource_group_workload" {
  type        = string
  default     = "management"
  description = "Workload name for RG naming convention when create_resource_group = true."
}

###############################################################
# LOG ANALYTICS
###############################################################
variable "log_ingestion_gb_per_day" {
  type        = number
  default     = 5
  description = "Expected log ingestion per day in GB (for SKU selection). >100 = CapacityReservation"

  validation {
    condition     = var.log_ingestion_gb_per_day >= 1
    error_message = "Must be at least 1 GB per day."
  }
}

variable "log_daily_quota_gb" {
  type        = number
  default     = 10
  description = "Daily quota for log ingestion in GB"

  validation {
    condition     = var.log_daily_quota_gb >= 1
    error_message = "Daily quota must be at least 1 GB."
  }
}

variable "log_retention_days" {
  type        = number
  default     = 30
  description = "Log Analytics retention in days"
}

variable "law_internet_ingestion_enabled" {
  type        = bool
  default     = true
  description = "Enable internet ingestion on LAW. Set to false after Private Endpoints are deployed."
}

variable "law_internet_query_enabled" {
  type        = bool
  default     = true
  description = "Enable internet query on LAW. Set to false after Private Endpoints are deployed."
}

variable "law_local_authentication_enabled" {
  type        = bool
  default     = false
  description = "Allow local (shared key) authentication on LAW. Best practice: false to force Azure AD only."
}

variable "aa_public_network_access_enabled" {
  type        = bool
  default     = false
  description = "Allow public network access on Automation Account. Set to false for AMPLS."
}

###############################################################
# SECURITY
###############################################################
variable "enable_cmk" {
  type        = bool
  default     = false
  description = "Enable Customer Managed Keys for encryption"
}

###############################################################
# TAGS
###############################################################
variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}
