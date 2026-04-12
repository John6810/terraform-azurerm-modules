###############################################################
# NAMING CONVENTION
###############################################################

variable "subscription_acronym" {
  description = "Subscription acronym (e.g. mgm, con)"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.subscription_acronym))
    error_message = "subscription_acronym must be 2 to 5 lowercase letters."
  }
}

variable "environment" {
  description = "Environment (e.g. prod, nprd)"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]{2,4}$", var.environment))
    error_message = "environment must be 2 to 4 lowercase letters."
  }
}

variable "region_code" {
  description = "Region code (e.g. gwc, weu)"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.region_code))
    error_message = "region_code must be 2 to 5 lowercase letters."
  }
}

variable "location" {
  description = "Azure region (e.g. germanywestcentral)"
  type        = string
  nullable    = false
}

###############################################################
# TAGS
###############################################################

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

###############################################################
# STORAGE
###############################################################

variable "storage_replication_type" {
  description = "Replication type for the storage account (LRS, ZRS)"
  type        = string
  default     = "LRS"
  nullable    = false

  validation {
    condition     = contains(["LRS", "ZRS"], var.storage_replication_type)
    error_message = "storage_replication_type must be LRS or ZRS."
  }
}

variable "export_retention_days" {
  description = "Number of days to retain raw exports in msexports container (0 = delete after processing)"
  type        = number
  default     = 0

  validation {
    condition     = var.export_retention_days >= 0
    error_message = "export_retention_days must be >= 0."
  }
}

variable "ingestion_retention_months" {
  description = "Number of months to retain ingested data in ingestion container"
  type        = number
  default     = 13

  validation {
    condition     = var.ingestion_retention_months >= 1
    error_message = "ingestion_retention_months must be >= 1."
  }
}

###############################################################
# AZURE DATA EXPLORER
###############################################################

variable "enable_data_explorer" {
  description = "Deploy Azure Data Explorer cluster and databases"
  type        = bool
  default     = true
}

variable "adx_sku_name" {
  description = "ADX cluster SKU name (e.g. Dev(No SLA)_Standard_D11_v2 for dev, Standard_D11_v2 for prod)"
  type        = string
  default     = "Dev(No SLA)_Standard_D11_v2"
  nullable    = false
}

variable "adx_sku_capacity" {
  description = "ADX cluster node count (1 for dev, 2+ for prod)"
  type        = number
  default     = 1

  validation {
    condition     = var.adx_sku_capacity >= 1
    error_message = "adx_sku_capacity must be >= 1."
  }
}

variable "adx_hot_cache_days" {
  description = "Number of days for ADX hot cache"
  type        = number
  default     = 31
}

variable "adx_soft_delete_days" {
  description = "Number of days for ADX soft delete retention"
  type        = number
  default     = 365
}

###############################################################
# COST MANAGEMENT EXPORTS
###############################################################

variable "cost_management_exports_principal_id" {
  description = "Principal ID of the Azure Cost Management Exports Service Principal (null = no role assignment)"
  type        = string
  default     = null
}

###############################################################
# NETWORKING
###############################################################

variable "enable_public_access" {
  description = "Enable public network access on storage and ADF. WARNING: bypasses firewall perimeter. Use Private Endpoints in production."
  type        = bool
  default     = false
}
