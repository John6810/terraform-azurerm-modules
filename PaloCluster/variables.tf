###############################################################
# NAMING CONVENTION
# The workload determines the suffix for all resource names:
#   RG  : rg-{sub}-{env}-{region}-{workload}
#   ILB : ilb-{sub}-{env}-{region}-{workload}-trust
#   AS  : as-{sub}-{env}-{region}-{workload}
#   VM  : fw-{sub}-{env}-{region}-{key}        (key = obew-01, obew-02, ...)
#   PIP : pip-{sub}-{env}-{region}-fw-{key}
#
# Example with workload = "palo-obew":
#   rg-con-prod-gwc-palo-obew
#   ilb-con-prod-gwc-palo-obew-trust
#   fw-con-prod-gwc-obew-01
###############################################################

variable "subscription_acronym" {
  type        = string
  nullable    = false
  description = "Subscription acronym (e.g. con)"

  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.subscription_acronym))
    error_message = "subscription_acronym must be 2 to 5 lowercase letters."
  }
}

variable "environment" {
  type        = string
  nullable    = false
  description = "Environment (e.g. prod, nprd)"

  validation {
    condition     = can(regex("^[a-z]{2,4}$", var.environment))
    error_message = "environment must be 2 to 4 lowercase letters."
  }
}

variable "region_code" {
  type        = string
  nullable    = false
  description = "Region code (e.g. gwc)"

  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.region_code))
    error_message = "region_code must be 2 to 5 lowercase letters."
  }
}

variable "workload" {
  type        = string
  nullable    = false
  description = "Workload / cluster name (e.g. palo-obew, palo-in)"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_-]{1,30}$", var.workload))
    error_message = "workload must be 2 to 31 characters: lowercase letters, digits, hyphens, underscores."
  }
}

variable "location" {
  type        = string
  nullable    = false
  description = "Azure region (e.g. germanywestcentral)."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to assign"
}

###############################################################
# NETWORK — Subnet IDs (existing, already deployed)
###############################################################

variable "subnet_mgmt_id" {
  type        = string
  nullable    = false
  description = "Management subnet ID for management NICs."
}

variable "subnet_untrust_id" {
  type        = string
  nullable    = false
  description = "Untrust subnet ID for external NICs."
}

variable "subnet_trust_id" {
  type        = string
  nullable    = false
  description = "Trust subnet ID for internal NICs (ILB)."
}

###############################################################
# INTERNAL LOAD BALANCER (trust)
###############################################################

variable "ilb_frontend_ip" {
  type        = string
  nullable    = false
  description = "Static private IP for the ILB frontend in the trust subnet (e.g. 10.238.200.36)."
}

variable "ilb_probe_port" {
  type        = number
  default     = 443
  description = "ILB health probe port."
}

variable "ilb_probe_threshold" {
  type        = number
  default     = 2
  description = "Number of consecutive probe failures before marking backend unhealthy."
}

variable "ilb_probe_interval" {
  type        = number
  default     = 5
  description = "Health probe interval in seconds."
}

###############################################################
# VM-SERIES INSTANCES
###############################################################

variable "firewalls" {
  type = map(object({
    mgmt_ip    = string
    untrust_ip = string
    trust_ip   = string
    zone       = optional(string)
  }))
  description = <<-EOT
    Map of firewall instances to deploy.
    The key is the name suffix (e.g. "obew-01", "obew-02").
    Example:
      firewalls = {
        "fw-01" = { mgmt_ip = "x.x.x.4",  untrust_ip = "x.x.x.20", trust_ip = "x.x.x.37", zone = "1" }
        "fw-02" = { mgmt_ip = "x.x.x.5",  untrust_ip = "x.x.x.21", trust_ip = "x.x.x.38", zone = "2" }
      }
  EOT
}

variable "vm_size" {
  type        = string
  nullable    = false
  default     = "Standard_DS3_v2"
  description = "VM size (4 vCPU, 14 GB RAM minimum recommended)."
}

variable "vm_image" {
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "paloaltonetworks"
    offer     = "vmseries-flex"
    sku       = "byol"
    version   = "latest"
  }
  description = "Palo Alto VM-Series marketplace image reference."
}

variable "panos_version" {
  type        = string
  nullable    = false
  default     = "11.1.607"
  description = "PAN-OS version (for reference/tags, actual version depends on the image)."
}

variable "admin_username" {
  type        = string
  nullable    = false
  default     = "panadmin"
  description = "Admin username for VM-Series instances."
}

variable "admin_password" {
  type        = string
  sensitive   = true
  default     = null
  description = "Admin password. If null and no SSH key provided, a random password is generated and stored in Key Vault (requires enable_disk_encryption = true)."

  validation {
    condition     = var.admin_password != null || var.admin_ssh_public_key != null || var.enable_disk_encryption
    error_message = "Either admin_password, admin_ssh_public_key, or enable_disk_encryption (for auto-generated password stored in KV) must be set."
  }
}

variable "admin_ssh_public_key" {
  type        = string
  default     = null
  description = "SSH public key for authentication. Mutually exclusive with admin_password."
}

variable "os_disk_size_gb" {
  type        = number
  default     = 80
  description = "OS disk size in GB."
}

variable "os_disk_storage_account_type" {
  type        = string
  default     = "Premium_LRS"
  description = "OS disk storage account type: Standard_LRS, StandardSSD_LRS, or Premium_LRS."

  validation {
    condition     = contains(["Standard_LRS", "StandardSSD_LRS", "Premium_LRS"], var.os_disk_storage_account_type)
    error_message = "os_disk_storage_account_type must be Standard_LRS, StandardSSD_LRS, or Premium_LRS."
  }
}

variable "accelerated_networking" {
  type        = bool
  default     = true
  description = "Enable accelerated networking on dataplane NICs (untrust + trust). Strongly recommended by Palo Alto for DPDK throughput."
}

variable "enable_boot_diagnostics" {
  type        = bool
  default     = false
  description = "Enable boot diagnostics for troubleshooting VM boot failures."
}

variable "boot_diagnostics_storage_uri" {
  type        = string
  default     = null
  description = "Storage account URI for boot diagnostics. If null with boot diagnostics enabled, uses managed storage."
}

###############################################################
# DISK ENCRYPTION (optional — Key Vault + key + DES per cluster)
###############################################################

variable "enable_disk_encryption" {
  type        = bool
  default     = true
  description = "Creates a Key Vault, RSA key and Disk Encryption Set for CMK OS disk encryption."
}

variable "kv_secrets_readers" {
  type        = list(string)
  default     = []
  description = "List of Entra ID group object IDs granted Key Vault Secrets User on the cluster KV."
}

variable "kv_allowed_ips" {
  type        = list(string)
  default     = []
  description = "Public IPs (CIDR /32) allowed to access the Key Vault. Azure Services are always allowed via bypass."
}

###############################################################
# MONITORING — Application Insights (optional)
###############################################################

variable "log_analytics_workspace_id" {
  type        = string
  default     = null
  description = "Log Analytics Workspace ID for Application Insights. If null, no APPI is created."
}

variable "panos_spn_object_id" {
  type        = string
  default     = null
  description = "PAN-OS SPN object ID (e.g. spn-prod-panos-001). Receives the custom AppInsights role on the subscription."
}

###############################################################
# BOOTSTRAP (optional)
###############################################################

variable "bootstrap_storage_account_name" {
  type        = string
  default     = null
  description = "Bootstrap storage account NAME (not ARM resource ID). PAN-OS expects the account name, not the full /subscriptions/.../storageAccounts/... path. If null, no bootstrap."
}

variable "bootstrap_share_name" {
  type        = string
  default     = null
  description = "File share name for bootstrap."
}

variable "bootstrap_share_directory" {
  type        = string
  default     = null
  description = "Optional subdirectory within the file share for bootstrap packages."
}

variable "bootstrap_storage_account_access_key" {
  type        = string
  sensitive   = true
  default     = null
  description = "Bootstrap storage account access key."
}
