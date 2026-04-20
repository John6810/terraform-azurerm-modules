###############################################################
# MODULE: Aks - Variables
###############################################################

###############################################################
# NAMING CONVENTION
###############################################################
variable "name" {
  type        = string
  default     = null
  description = "Explicit cluster name. If null, computed automatically."
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
  description = "Workload name (e.g. 001, apim)"

  validation {
    condition     = var.workload == null || can(regex("^[a-z0-9][a-z0-9_-]{0,30}$", var.workload))
    error_message = "workload must be 1 to 31 characters: lowercase letters, digits, hyphens, underscores."
  }
}

variable "dns_prefix" {
  type        = string
  default     = null
  description = "Cluster DNS prefix. If null, derived from name."
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

variable "node_subnet_id" {
  type        = string
  description = "Subnet ID for AKS nodes"
  nullable    = false
}

variable "cluster_identity_id" {
  type        = string
  description = "User Assigned Managed Identity ID for the cluster"
  nullable    = false
}

variable "kubelet_identity_id" {
  type        = string
  description = "Kubelet Managed Identity ID"
  nullable    = false
}

variable "kubelet_identity_client_id" {
  type        = string
  description = "Kubelet Identity client ID"
  nullable    = false
}

variable "kubelet_identity_object_id" {
  type        = string
  description = "Kubelet Identity object ID (principal ID)"
  nullable    = false
}

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID for AKS RBAC"
  nullable    = false
}

###############################################################
# CLUSTER CONFIGURATION
###############################################################
variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version (e.g. 1.30). Null = latest."
  default     = null
}

variable "sku_tier" {
  type        = string
  description = "SKU tier: Free, Standard, Premium"
  default     = "Standard"

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be Free, Standard, or Premium."
  }
}

variable "node_resource_group_name" {
  type        = string
  default     = null
  description = "Node resource group name. If null, computed automatically."
}

variable "automatic_upgrade_channel" {
  type        = string
  description = "Automatic upgrade channel: none, patch, rapid, stable, node-image"
  default     = "stable"

  validation {
    condition     = contains(["none", "patch", "rapid", "stable", "node-image"], var.automatic_upgrade_channel)
    error_message = "automatic_upgrade_channel must be one of: none, patch, rapid, stable, node-image."
  }
}

###############################################################
# PRIVATE CLUSTER
###############################################################
variable "private_dns_zone_id" {
  type        = string
  description = "Private DNS Zone ID. 'None' = ALZ policy manages DNS. 'System' = auto in node RG."
  default     = "None"
}

variable "api_server_subnet_id" {
  type        = string
  description = "Dedicated subnet ID for API Server VNet Integration. Null = disabled."
  default     = null
}

###############################################################
# NETWORK PROFILE — Azure CNI Overlay
###############################################################
variable "network_policy" {
  type        = string
  description = "Network policy: azure, calico, cilium"
  default     = "azure"

  validation {
    condition     = contains(["azure", "calico", "cilium"], var.network_policy)
    error_message = "network_policy must be azure, calico, or cilium."
  }
}

variable "pod_cidr" {
  type        = string
  description = "CIDR for pods (overlay)"
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  type        = string
  description = "CIDR for Kubernetes services"
  default     = "172.16.0.0/16"
}

variable "dns_service_ip" {
  type        = string
  description = "Kubernetes DNS service IP (within service_cidr)"
  default     = "172.16.0.10"
}

variable "outbound_type" {
  type        = string
  description = "Outbound type: loadBalancer, userDefinedRouting, managedNATGateway"
  default     = "userDefinedRouting"

  validation {
    condition     = contains(["loadBalancer", "userDefinedRouting", "managedNATGateway"], var.outbound_type)
    error_message = "outbound_type must be loadBalancer, userDefinedRouting, or managedNATGateway."
  }
}

###############################################################
# SYSTEM NODE POOL
###############################################################
variable "system_pool_vm_size" {
  type        = string
  description = "VM SKU for the system pool"
  default     = "Standard_D4s_v5"
}

variable "system_pool_node_count" {
  type        = number
  description = "Node count (when autoscaling is disabled)"
  default     = 3
}

variable "system_pool_auto_scaling" {
  type        = bool
  description = "Enable autoscaling on the system pool"
  default     = false
}

variable "system_pool_min_count" {
  type        = number
  description = "Minimum nodes (autoscaling)"
  default     = 3
}

variable "system_pool_max_count" {
  type        = number
  description = "Maximum nodes (autoscaling)"
  default     = 5
}

variable "system_pool_os_disk_type" {
  type        = string
  description = "OS disk type: Ephemeral or Managed"
  default     = "Ephemeral"

  validation {
    condition     = contains(["Ephemeral", "Managed"], var.system_pool_os_disk_type)
    error_message = "system_pool_os_disk_type must be Ephemeral or Managed."
  }
}

variable "system_pool_os_disk_size_gb" {
  type        = number
  description = "OS disk size in GB"
  default     = 128
}

variable "system_pool_host_encryption_enabled" {
  type        = bool
  default     = false
  description = <<-EOT
  Enables Encryption at Host on the system node pool. Encrypts temp disk,
  cache, and pagefile at the hypervisor level (complements etcd KMS v2
  which is cluster-wide).

  Prerequisite: 'Microsoft.Compute/EncryptionAtHost' feature must be
  registered on the subscription:
    az feature register --namespace Microsoft.Compute --name EncryptionAtHost
    az provider register --namespace Microsoft.Compute

  Requires a compatible VM size (Dsv4+, Esv4+, Ddsv5+, etc.).
  Toggling this flag triggers a rotation of the node pool (surge + drain).
  EOT
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones"
  default     = ["1", "2", "3"]
}

variable "upgrade_max_surge" {
  type        = string
  description = "Max surge for node upgrades"
  default     = "33%"
}

###############################################################
# USER NODE POOLS
###############################################################
variable "user_node_pools" {
  description = <<-EOT
  A map of user node pool configurations. The map key is deliberately
  arbitrary to avoid issues where map keys may be unknown at plan time.

  - `name`                        - (Required) Node pool name (max 12 chars, lowercase alphanumeric).
  - `vm_size`                     - (Required) VM SKU.
  - `min_count`                   - (Required) Minimum nodes.
  - `max_count`                   - (Required) Maximum nodes.
  - `node_count`                  - (Optional) Fixed node count (when autoscaling disabled).
  - `enable_auto_scaling`         - (Optional) Enable autoscaling. Defaults to true.
  - `os_disk_type`                - (Optional) Ephemeral or Managed. Defaults to Ephemeral.
  - `os_disk_size_gb`             - (Optional) OS disk size in GB.
  - `zones`                       - (Optional) Availability zones. Defaults to cluster zones.
  - `labels`                      - (Optional) Node labels.
  - `taints`                      - (Optional) Node taints.
  - `temporary_name_for_rotation` - (Optional) Temp name for rotation (max 12 chars).
  - `host_encryption_enabled`     - (Optional) Enables Encryption at Host on the pool. Defaults to false. Requires feature registration.
  EOT
  type = map(object({
    name                        = string
    vm_size                     = string
    min_count                   = number
    max_count                   = number
    node_count                  = optional(number)
    enable_auto_scaling         = optional(bool, true)
    os_disk_type                = optional(string, "Ephemeral")
    os_disk_size_gb             = optional(number)
    zones                       = optional(list(string))
    labels                      = optional(map(string), {})
    taints                      = optional(list(string), [])
    temporary_name_for_rotation = optional(string)
    host_encryption_enabled     = optional(bool, false)
  }))
  default  = {}
  nullable = false
}

###############################################################
# MAINTENANCE, IMAGE CLEANER, NODE OS UPGRADE
###############################################################
variable "maintenance_window" {
  description = "AKS maintenance window (day + UTC hours)"
  type = object({
    day        = string
    hour_start = number
    hour_end   = number
  })
  default = null
}

variable "image_cleaner_enabled" {
  type        = bool
  description = "Enable Image Cleaner to remove unused images"
  default     = false
}

variable "vertical_pod_autoscaler_enabled" {
  type        = bool
  default     = false
  description = <<-EOT
  Enables the Vertical Pod Autoscaler addon (recommender, updater,
  admission-controller). Per-workload mode is configured via
  VerticalPodAutoscaler CRDs in Kubernetes:
    updateMode: "Off"     -> recommend-only, no mutation (safe dry-run)
    updateMode: "Initial" -> apply at pod creation
    updateMode: "Auto"    -> resize live (intrusive, kills+recreates pods)

  Enabling the addon is safe — workloads must explicitly opt-in by
  creating a VPA object.
  EOT
}

variable "keda_enabled" {
  type        = bool
  default     = false
  description = "Enable KEDA (Kubernetes Event-Driven Autoscaler) addon."
}

variable "image_cleaner_interval_hours" {
  type        = number
  description = "Interval in hours for image cleanup"
  default     = 48
}

variable "node_os_upgrade_channel" {
  type        = string
  description = "Node OS upgrade channel: Unmanaged, SecurityPatch, NodeImage, None"
  default     = "NodeImage"

  validation {
    condition     = contains(["Unmanaged", "SecurityPatch", "NodeImage", "None"], var.node_os_upgrade_channel)
    error_message = "node_os_upgrade_channel must be Unmanaged, SecurityPatch, NodeImage, or None."
  }
}

###############################################################
# KMS V2 ENCRYPTION
###############################################################
variable "kms_key_id" {
  type        = string
  description = "Key Vault key ID for KMS v2 encryption. Null = no KMS."
  default     = null
}

variable "kms_key_vault_id" {
  type        = string
  description = "Key Vault resource ID for KMS. Required when key_vault_network_access = Private."
  default     = null
}

###############################################################
# MONITORING
###############################################################
variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics Workspace ID for Defender and diagnostics"
  default     = null
}

###############################################################
# TAGS
###############################################################
variable "tags" {
  type        = map(string)
  description = "Tags"
  default     = {}
}
