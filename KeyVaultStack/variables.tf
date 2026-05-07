###############################################################
# MODULE: KeyVaultStack - Variables
# RG + Key Vault + Private Endpoint
###############################################################

###############################################################
# NAMING CONVENTION
###############################################################
variable "subscription_acronym" {
  type        = string
  description = "Subscription acronym for naming convention (e.g. api, mgm, con)"

  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.subscription_acronym))
    error_message = "subscription_acronym must be 2 to 5 lowercase letters."
  }
}

variable "environment" {
  type        = string
  description = "Environment for naming convention (e.g. prod, nprd)"

  validation {
    condition     = can(regex("^[a-z]{2,4}$", var.environment))
    error_message = "environment must be 2 to 4 lowercase letters."
  }
}

variable "region_code" {
  type        = string
  description = "Region code for naming convention (e.g. gwc, weu)"

  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.region_code))
    error_message = "region_code must be 2 to 5 lowercase letters."
  }
}

variable "workload" {
  type        = string
  description = "Workload name for naming convention. Keep short (max 24 chars total for KV name)."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.workload))
    error_message = "workload must be 2 to 31 characters: lowercase letters, digits, hyphens."
  }
}

###############################################################
# REQUIRED VARIABLES
###############################################################
variable "location" {
  type        = string
  description = "Azure region where resources will be deployed"
  nullable    = false
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for the Key Vault Private Endpoint"
  nullable    = false

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.subnet_id))
    error_message = "Subnet ID must be a valid Azure resource ID."
  }
}

###############################################################
# RESOURCE GROUP OWNERSHIP
###############################################################
variable "create_resource_group" {
  type        = bool
  description = "When true (default), the module creates and owns its RG (rg-{prefix}-{workload}) plus optional lock and role assignments. When false, the RG must be provided via resource_group_name (e.g. from a ResourceGroupSet) — the module skips RG creation, RG-level lock, and RG-level role_assignments (those become the consumer's responsibility)."
  default     = true
}

variable "resource_group_name" {
  type        = string
  description = "Existing RG name to deploy into when create_resource_group=false. Ignored when create_resource_group=true (RG name is computed from naming convention)."
  default     = null

  validation {
    condition     = var.resource_group_name == null || can(regex("^[a-zA-Z0-9_().-]{1,89}[a-zA-Z0-9_()-]$", var.resource_group_name))
    error_message = "resource_group_name must match Azure RG naming rules (1-90 chars, alphanumerics/underscores/parentheses/hyphens/periods, not ending in period)."
  }

  validation {
    condition     = var.create_resource_group == true || var.resource_group_name != null
    error_message = "resource_group_name is required when create_resource_group=false."
  }
}

###############################################################
# NAMING OVERRIDES
###############################################################
variable "kv_suffix" {
  type        = string
  default     = null
  description = "Optional. Suffix for the KV and PE name. If null, uses the workload."
}

variable "kv_name" {
  type        = string
  default     = null
  description = "Optional. Explicit Key Vault name (3-24 chars). If null, computed."

  validation {
    condition     = var.kv_name == null || (length(var.kv_name) >= 3 && length(var.kv_name) <= 24 && can(regex("^[a-zA-Z][a-zA-Z0-9-]*[a-zA-Z0-9]$", var.kv_name)))
    error_message = "Key Vault name must be 3-24 characters, start with a letter, end with a letter or digit, and contain only letters, digits, and hyphens."
  }
}

###############################################################
# KEY VAULT CONFIGURATION
###############################################################
variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID for the Key Vault (auto-detected if null)"
  default     = null

  validation {
    condition     = var.tenant_id == null || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.tenant_id))
    error_message = "Tenant ID must be a valid GUID format."
  }
}

variable "sku_name" {
  type        = string
  description = "SKU name: 'standard' or 'premium' (HSM-backed)"
  default     = "premium"

  validation {
    condition     = contains(["standard", "premium"], var.sku_name)
    error_message = "SKU must be 'standard' or 'premium'."
  }
}

variable "enable_rbac" {
  type        = bool
  description = "Enable RBAC authorization (recommended over access policies)"
  default     = true
}

variable "assign_rbac_to_current_user" {
  type        = bool
  description = "Automatically assign Key Vault Administrator role to current deployer"
  default     = true
}

variable "enabled_for_disk_encryption" {
  type        = bool
  description = "Enable Azure Disk Encryption to retrieve secrets and unwrap keys"
  default     = false
}

variable "enabled_for_deployment" {
  type        = bool
  description = "Enable VMs to retrieve certificates stored as secrets"
  default     = false
}

variable "enabled_for_template_deployment" {
  type        = bool
  description = "Enable ARM templates to retrieve secrets"
  default     = false
}

variable "soft_delete_retention_days" {
  type        = number
  description = "Number of days to retain soft-deleted Key Vault (7-90)"
  default     = 90

  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "Soft delete retention days must be between 7 and 90."
  }
}

variable "purge_protection_enabled" {
  type        = bool
  description = "Enable purge protection (IRREVERSIBLE once enabled)"
  default     = true
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Enable public network access (disable in production)"
  default     = false
}

variable "network_acls" {
  description = "Network ACLs configuration for Key Vault firewall"
  type = object({
    default_action = string
    bypass         = string
    ip_rules       = optional(list(string), [])
    subnet_ids     = optional(list(string), [])
  })
  default = null

  validation {
    condition     = var.network_acls == null || contains(["Allow", "Deny"], var.network_acls.default_action)
    error_message = "network_acls.default_action must be 'Allow' or 'Deny'."
  }

  validation {
    condition     = var.network_acls == null || contains(["AzureServices", "None"], var.network_acls.bypass)
    error_message = "network_acls.bypass must be 'AzureServices' or 'None'."
  }
}

###############################################################
# RESOURCE GROUP — LOCK & RBAC
###############################################################
variable "lock" {
  type = object({
    kind = string
    name = optional(string)
  })
  default     = null
  description = <<-EOT
  Management lock on the resource group.

  - `kind` - (Required) "CanNotDelete" or "ReadOnly".
  - `name` - (Optional) Lock name. Generated from kind if not specified.
  EOT

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "Lock kind must be either \"CanNotDelete\" or \"ReadOnly\"."
  }
}

variable "role_assignments" {
  description = <<-EOT
  A map of role assignments to create on the resource group. The map key is deliberately
  arbitrary to avoid issues where map keys may be unknown at plan time.

  - `role_definition_id_or_name` - (Required) The ID or name of the role definition.
  - `principal_id`               - (Required) The ID of the principal to assign the role to.
  - `principal_type`             - (Optional) User, Group, or ServicePrincipal.
  - `condition`                  - (Optional) ABAC condition.
  - `condition_version`          - (Optional) Condition version ("2.0").
  - `description`                - (Optional) Description.
  - `skip_service_principal_aad_check` - (Optional) Skip AAD check.
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

###############################################################
# PRIVATE ENDPOINT CONFIGURATION
###############################################################
variable "private_dns_zone_ids" {
  type        = list(string)
  description = "Private DNS Zone IDs for the Private Endpoint (e.g. privatelink.vaultcore.azure.net)"
  default     = null
}

variable "pe_private_ip_address" {
  type        = string
  description = "Optional. Static private IP for the Private Endpoint."
  default     = null

  validation {
    condition     = var.pe_private_ip_address == null || can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$", var.pe_private_ip_address))
    error_message = "pe_private_ip_address must be a valid IPv4 address."
  }
}

variable "pe_custom_network_interface_name" {
  type        = string
  description = "Optional. Custom network interface name for the Private Endpoint."
  default     = null
}

###############################################################
# TAGS
###############################################################
variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}
