###############################################################
# MODULE: StorageAccount - Variables
###############################################################

###############################################################
# NAMING CONVENTION
# Storage Account: lowercase alphanumeric only, 3-24 chars
# Convention: st{subscription_acronym}{environment}{region_code}{workload}
###############################################################
variable "name" {
  type        = string
  default     = null
  description = "Explicit name. If null, computed automatically."

  validation {
    condition     = var.name == null || can(regex("^[a-z0-9]{3,24}$", var.name))
    error_message = "Storage Account name must be 3-24 lowercase alphanumeric characters."
  }
}

variable "subscription_acronym" {
  type        = string
  default     = null
  description = "Subscription acronym (e.g. api, mgm)"

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
  description = "Workload suffix. Lowercase alphanumeric only (no hyphens)."

  validation {
    condition     = var.workload == null || can(regex("^[a-z][a-z0-9]{0,15}$", var.workload))
    error_message = "workload must be 1-16 lowercase alphanumeric characters."
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
  description = "Resource group name"
  nullable    = false
}

###############################################################
# STORAGE CONFIGURATION
###############################################################
variable "account_tier" {
  type        = string
  description = "Tier: Standard or Premium"
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.account_tier)
    error_message = "account_tier must be 'Standard' or 'Premium'."
  }
}

variable "account_replication_type" {
  type        = string
  description = "Replication type: LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS"
  default     = "ZRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.account_replication_type)
    error_message = "account_replication_type must be one of: LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS."
  }
}

variable "account_kind" {
  type        = string
  description = "Kind: StorageV2, BlobStorage, BlockBlobStorage, FileStorage"
  default     = "StorageV2"

  validation {
    condition     = contains(["StorageV2", "BlobStorage", "BlockBlobStorage", "FileStorage"], var.account_kind)
    error_message = "account_kind must be one of: StorageV2, BlobStorage, BlockBlobStorage, FileStorage."
  }
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Enable public network access"
  default     = false
}

variable "shared_access_key_enabled" {
  type        = bool
  description = "Enable shared access keys (account keys / connection strings). Disable to force AAD-only auth — required by some compliance baselines (MCSB, F-STOR-2)."
  default     = false
}

variable "default_to_oauth_authentication" {
  type        = bool
  description = "When true, the portal/CLI default to AAD OAuth instead of access keys for data plane operations. Recommended when shared_access_key_enabled is true to nudge admins away from key auth."
  default     = false
}

variable "cross_tenant_replication_enabled" {
  type        = bool
  description = "Allow object replication across Azure AD tenants. Default false (Azure v4 default) — keeps data inside the tenant."
  default     = false
}

variable "infrastructure_encryption_enabled" {
  type        = bool
  description = "Enable infrastructure-level AES-256 encryption (double encryption). Adds a second encryption layer below the service-level encryption. Cannot be changed after creation."
  default     = false
}

variable "local_user_enabled" {
  type        = bool
  description = "Enable local users for SFTP/NFS. Default true (Azure default) — set false to disable when SFTP/NFS is not used."
  default     = true
}

variable "customer_managed_key" {
  description = <<-EOT
  Customer-Managed Key (CMK) configuration backed by Azure Key Vault. When set,
  the storage account encrypts all data with this CMK instead of the
  Microsoft-managed key.

  - `key_vault_key_id`           - (Required) Versioned or versionless key URL
                                    (e.g. https://kv-...vault.azure.net/keys/foo
                                    or .../keys/foo/<version>).
  - `user_assigned_identity_id`  - (Required) UAMI that has Key Vault Crypto
                                    Service Encryption User on the KV.

  Prerequisites:
  - identity_type must include "UserAssigned" and reference the same UAMI.
  - The UAMI needs Key Vault Crypto Service Encryption User on the KV.
  - The KV must have purge protection enabled.
  EOT
  type = object({
    key_vault_key_id          = string
    user_assigned_identity_id = string
  })
  default = null
}

variable "identity_type" {
  type        = string
  description = "Identity type: SystemAssigned, UserAssigned, or SystemAssigned,UserAssigned"
  default     = null

  validation {
    condition     = var.identity_type == null || contains(["SystemAssigned", "UserAssigned", "SystemAssigned,UserAssigned"], var.identity_type)
    error_message = "identity_type must be 'SystemAssigned', 'UserAssigned', or 'SystemAssigned,UserAssigned'."
  }
}

variable "identity_ids" {
  type        = list(string)
  description = "List of UAMI resource IDs to attach when identity_type contains 'UserAssigned'. The CMK UAMI (var.customer_managed_key.user_assigned_identity_id) is auto-merged with these — no need to repeat it here."
  default     = []
  nullable    = false
}

variable "blob_delete_retention_days" {
  type        = number
  description = "Retention days for deleted blobs"
  default     = 30

  validation {
    condition     = var.blob_delete_retention_days >= 1 && var.blob_delete_retention_days <= 365
    error_message = "blob_delete_retention_days must be between 1 and 365."
  }
}

variable "container_delete_retention_days" {
  type        = number
  description = "Retention days for deleted containers"
  default     = 30

  validation {
    condition     = var.container_delete_retention_days >= 1 && var.container_delete_retention_days <= 365
    error_message = "container_delete_retention_days must be between 1 and 365."
  }
}

variable "blob_versioning_enabled" {
  type        = bool
  description = "Enable blob versioning. Required for tfstate backends (F-STOR-3) and for point-in-time restore. Default false (Azure default) — opt-in."
  default     = false
}

variable "blob_change_feed_enabled" {
  type        = bool
  description = "Enable the blob change feed (audit log of all blob changes). Pre-requisite for some replication and governance scenarios. Default false."
  default     = false
}

variable "blob_last_access_time_enabled" {
  type        = bool
  description = "Track last-access time on blobs. Required for lifecycle management policies that move/delete based on access patterns. Adds ingestion cost — opt-in."
  default     = false
}

variable "containers" {
  description = <<-EOT
  A map of containers to create in the Storage Account. The map key is arbitrary.

  - `name`        - (Required) Container name.
  - `access_type` - (Optional) Access type: private, blob, or container. Defaults to private.
  EOT
  type = map(object({
    name        = string
    access_type = optional(string, "private")
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for c in var.containers : contains(["private", "blob", "container"], c.access_type)
    ])
    error_message = "Container access_type must be 'private', 'blob', or 'container'."
  }
}

###############################################################
# FILE SHARES (Azure Files)
###############################################################
variable "file_shares" {
  description = <<-EOT
  A map of file shares to create on the Storage Account (requires account_kind = FileStorage for Premium).

  - `name`        - (Required) File share name (3-63 chars, lowercase, numbers, hyphens).
  - `quota_gb`    - (Required) Provisioned capacity in GiB (Premium min 100, max 102400).
  - `access_tier` - (Optional) "Premium" for FileStorage, or Hot/Cool/TransactionOptimized for Standard.
  EOT
  type = map(object({
    name        = string
    quota_gb    = number
    access_tier = optional(string)
  }))
  default  = {}
  nullable = false
}

###############################################################
# AZURE FILES AUTHENTICATION (Entra Kerberos / AD DS / AADDS)
###############################################################
variable "azure_files_authentication" {
  description = <<-EOT
  Identity-based authentication for Azure Files shares.

  - `directory_type`                 - (Required) "AADDS", "AD", or "AADKERB" (Entra Kerberos).
  - `default_share_level_permission` - (Optional) Default RBAC at share level: None, StorageFileDataSmbShareReader,
                                       StorageFileDataSmbShareContributor, StorageFileDataSmbShareElevatedContributor.
  EOT
  type = object({
    directory_type                 = string
    default_share_level_permission = optional(string)
  })
  default = null

  validation {
    condition     = var.azure_files_authentication == null || contains(["AADDS", "AD", "AADKERB"], try(var.azure_files_authentication.directory_type, ""))
    error_message = "directory_type must be 'AADDS', 'AD', or 'AADKERB'."
  }
}

###############################################################
# NETWORK RULES (firewall + VNet service endpoints)
###############################################################
variable "network_rules" {
  description = <<-EOT
  Storage Account firewall rules. When null, no network_rules block is created (portal default).

  - `default_action`             - (Required) "Allow" or "Deny".
  - `bypass`                     - (Optional) Services allowed to bypass: list of AzureServices, Logging, Metrics, None.
  - `virtual_network_subnet_ids` - (Optional) Subnet IDs with service endpoint to Microsoft.Storage.
  - `ip_rules`                   - (Optional) IPv4 CIDR ranges allowed.
  EOT
  type = object({
    default_action             = string
    bypass                     = optional(list(string), ["AzureServices"])
    virtual_network_subnet_ids = optional(list(string), [])
    ip_rules                   = optional(list(string), [])
  })
  default = null

  validation {
    condition     = var.network_rules == null || contains(["Allow", "Deny"], try(var.network_rules.default_action, ""))
    error_message = "network_rules.default_action must be 'Allow' or 'Deny'."
  }
}

###############################################################
# RBAC & LOCK
###############################################################
variable "role_assignments" {
  description = <<-EOT
  A map of role assignments to create on this Storage Account. The map key is arbitrary.

  - `role_definition_id_or_name`             - (Required) The ID or name of the role definition.
  - `principal_id`                           - (Required) The ID of the principal.
  - `principal_type`                         - (Optional) User, Group, or ServicePrincipal.
  - `condition`                              - (Optional) ABAC condition.
  - `condition_version`                      - (Optional) Condition version ("2.0").
  - `description`                            - (Optional) Description.
  - `skip_service_principal_aad_check`       - (Optional) Skip AAD check.
  - `delegated_managed_identity_resource_id` - (Optional) Cross-tenant.
  EOT
  type = map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    principal_type                         = optional(string)
    condition                              = optional(string)
    condition_version                      = optional(string)
    description                            = optional(string)
    skip_service_principal_aad_check       = optional(bool, false)
    delegated_managed_identity_resource_id = optional(string)
  }))
  default  = {}
  nullable = false
}

variable "lock" {
  type = object({
    kind = string
    name = optional(string)
  })
  default     = null
  description = <<-EOT
  Controls the Resource Lock configuration.

  - `kind` - (Required) "CanNotDelete" or "ReadOnly".
  - `name` - (Optional) Lock name. Generated from kind if not specified.
  EOT

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "Lock kind must be either \"CanNotDelete\" or \"ReadOnly\"."
  }
}

###############################################################
# TAGS
###############################################################
variable "tags" {
  type        = map(string)
  description = "Tags"
  default     = {}
}
