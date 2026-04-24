###############################################################
# MODULE: AvdSessionHost - Variables
###############################################################

###############################################################
# NAMING
# Azure VM:  vm-{sub_acronym}-{env}-{region_code}-{workload}-{index}
# Computer:  {computer_name_prefix}{index}   (max 15 chars total — NetBIOS)
###############################################################
variable "subscription_acronym" {
  type     = string
  nullable = false

  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.subscription_acronym))
    error_message = "subscription_acronym must be 2 to 5 lowercase letters."
  }
}

variable "environment" {
  type     = string
  nullable = false

  validation {
    condition     = can(regex("^[a-z]{2,4}$", var.environment))
    error_message = "environment must be 2 to 4 lowercase letters."
  }
}

variable "region_code" {
  type     = string
  nullable = false

  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.region_code))
    error_message = "region_code must be 2 to 5 lowercase letters."
  }
}

variable "workload" {
  type        = string
  description = "Workload suffix for VM naming (e.g. sh for session host)."
  default     = "sh"
}

variable "computer_name_prefix" {
  type        = string
  description = "Windows computer name prefix (≤ 12 chars; 2 digits appended). Lowercase alphanumeric."
  default     = null

  validation {
    condition     = var.computer_name_prefix == null || can(regex("^[a-z][a-z0-9]{0,11}$", var.computer_name_prefix))
    error_message = "computer_name_prefix must be 1-12 lowercase alphanumeric chars (starts with a letter)."
  }
}

###############################################################
# REQUIRED
###############################################################
variable "location" {
  type     = string
  nullable = false
}

variable "resource_group_name" {
  type     = string
  nullable = false
}

variable "subnet_id" {
  type     = string
  nullable = false

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.subnet_id))
    error_message = "subnet_id must be a valid subnet resource ID."
  }
}

###############################################################
# VM CONFIGURATION
###############################################################
variable "vm_count" {
  type        = number
  description = "Number of session hosts to create."
  default     = 1

  validation {
    condition     = var.vm_count >= 1 && var.vm_count <= 100
    error_message = "vm_count must be between 1 and 100."
  }
}

variable "vm_size" {
  type        = string
  description = "VM size. D4s_v5 recommended for Win11 multi-session (min 4 vCPU)."
  default     = "Standard_D4s_v5"
}

variable "availability_zones" {
  type        = list(string)
  description = "Zones to spread VMs across (round-robin). Empty = no zone placement."
  default     = ["1", "2", "3"]
}

variable "image" {
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = optional(string, "latest")
  })
  description = "Marketplace image. Default: Win11 24H2 AVD multi-session (FSLogix pre-installed)."
  default = {
    publisher = "microsoftwindowsdesktop"
    offer     = "windows-11"
    sku       = "win11-24h2-avd"
    version   = "latest"
  }
}

variable "os_disk" {
  type = object({
    storage_account_type = optional(string, "Premium_LRS")
    caching              = optional(string, "ReadWrite")
    disk_size_gb         = optional(number, 128)
    ephemeral            = optional(bool, true) # D4s_v5 has 150 GiB temp — fits 128 GiB ephemeral
  })
  default = {}
}

variable "admin_username" {
  type        = string
  description = "Local admin username (for break-glass access)."
  default     = "azureadmin"
}

variable "admin_password_kv_id" {
  type        = string
  description = "Key Vault ID holding the local admin password secret."
  nullable    = false

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.KeyVault/vaults/[^/]+$", var.admin_password_kv_id))
    error_message = "admin_password_kv_id must be a valid Key Vault resource ID."
  }
}

variable "admin_password_secret_name" {
  type        = string
  description = "Name of the Key Vault secret holding the local admin password."
  default     = "sh-local-admin-password"
}

variable "enable_trusted_launch" {
  type        = bool
  description = "Enable Trusted Launch (vTPM + Secure Boot). Recommended."
  default     = true
}

###############################################################
# AVD AGENT / SESSION HOST REGISTRATION
###############################################################
variable "hostpool_name" {
  type        = string
  description = "Host pool name to register the session host with (passed to AVD DSC)."
  nullable    = false
}

variable "hostpool_registration_token" {
  type        = string
  description = "Registration token from azurerm_virtual_desktop_host_pool_registration_info."
  sensitive   = true
  nullable    = false
}

variable "avd_dsc_artifact_url" {
  type        = string
  description = "URL of the AVD DSC Configuration.zip (Azure-hosted artifact)."
  default     = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02990.697.zip"
}

###############################################################
# FSLOGIX CONFIGURATION (registry via CustomScriptExtension)
###############################################################
variable "fslogix_vhd_location" {
  type        = string
  description = "SMB UNC path to FSLogix profiles share (e.g. \\\\\\\\<sa>.file.core.windows.net\\\\profiles)."
  nullable    = false
}

variable "fslogix_profile_size_mb" {
  type        = number
  description = "FSLogix container max size in MB."
  default     = 30000
}

###############################################################
# TAGS
###############################################################
variable "tags" {
  type    = map(string)
  default = {}
}
