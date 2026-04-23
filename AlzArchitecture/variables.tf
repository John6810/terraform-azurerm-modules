###############################################################
# CORE
###############################################################
variable "architecture_name" {
  type        = string
  default     = "prod"
  description = "ALZ architecture name"
}

variable "management_root_id" {
  type        = string
  nullable    = false
  description = "Parent management group ID (tenant root)"
}

variable "location" {
  type        = string
  nullable    = false
  description = "Azure region"
}

###############################################################
# HIERARCHY SETTINGS
###############################################################
variable "management_group_hierarchy_settings" {
  type = object({
    default_management_group_name            = string
    require_authorization_for_group_creation = optional(bool, true)
    update_existing                          = optional(bool, false)
  })
  default     = null
  description = "Tenant-level hierarchy settings. Sets default MG for new subs and restricts MG creation."
}

###############################################################
# SUBSCRIPTIONS
###############################################################
variable "subscription_placement" {
  type = map(object({
    subscription_id       = string
    management_group_name = string
  }))
  nullable    = false
  description = "Map of subscription placements in management groups"
}

variable "management_subscription_id" {
  type        = string
  nullable    = false
  description = "Management subscription ID"
}

variable "connectivity_subscription_id" {
  type        = string
  nullable    = false
  description = "Connectivity subscription ID"
}

###############################################################
# POLICY - AMBA
###############################################################
variable "alert_severity" {
  type        = list(string)
  default     = ["Sev0", "Sev1", "Sev2", "Sev3", "Sev4"]
  description = "Severity levels for alert notifications"
}

variable "email_security_contact" {
  type        = string
  default     = ""
  description = "Email for Defender for Cloud security contact"
}

variable "defender_plans" {
  type = object({
    app_services                      = optional(string, "DeployIfNotExists")
    arm                               = optional(string, "DeployIfNotExists")
    containers                        = optional(string, "DeployIfNotExists")
    cosmos_dbs                        = optional(string, "DeployIfNotExists")
    cspm                              = optional(string, "DeployIfNotExists")
    key_vault                         = optional(string, "DeployIfNotExists")
    oss_db                            = optional(string, "DeployIfNotExists")
    servers                           = optional(string, "DeployIfNotExists")
    servers_vulnerability_assessments = optional(string, "DeployIfNotExists")
    sql                               = optional(string, "DeployIfNotExists")
    sql_on_vm                         = optional(string, "DeployIfNotExists")
    storage                           = optional(string, "DeployIfNotExists")
  })
  default     = {}
  description = <<-EOT
  Defender for Cloud plan activation, passed to Deploy-MDFC-Config-H224 via
  policy_assignments_to_modify. Each plan value must be either
  "DeployIfNotExists" (enables the plan at Standard pricing) or "Disabled"
  (skips the plan).

  Default: all plans enabled (pay-per-use with 0 resources ≈ 0 cost,
  auto-coverage when a workload is deployed). Override individual plans
  by setting them to "Disabled" if your org has a specific exclusion.

  Note: Defender for APIs is not exposed by the Deploy-MDFC-Config_20240319
  policySet and must be managed out-of-band (or via a future policy version).
  EOT
  nullable    = false

  validation {
    condition = alltrue([
      for k, v in var.defender_plans :
      contains(["DeployIfNotExists", "Disabled"], v)
    ])
    error_message = "Each defender_plans value must be 'DeployIfNotExists' or 'Disabled'."
  }
}

variable "amba_resource_group_name" {
  type        = string
  default     = "rg-amba-monitoring-001"
  description = "Resource group name for AMBA monitoring"
}

variable "amba_resource_group_tags" {
  type        = map(string)
  default     = {}
  description = "Tags for the AMBA resource group"
}

variable "amba_disable_tag_name" {
  type        = string
  default     = "MonitorDisable"
  description = "Tag name to disable monitoring at resource level"
}

variable "amba_disable_tag_values" {
  type        = list(string)
  default     = ["true", "Test", "Dev", "Sandbox"]
  description = "Tag values to disable monitoring"
}

variable "action_group_email" {
  type        = list(string)
  default     = []
  description = "Action group email addresses"
}

###############################################################
# DEPENDENCIES (outputs from other modules)
###############################################################
variable "ddos_protection_plan_id" {
  type        = string
  nullable    = false
  description = "DDoS Protection Plan resource ID"
}

variable "ama_identity_id" {
  type        = string
  nullable    = false
  description = "AMA User Assigned Identity ID"
}

variable "action_group_ids" {
  type        = list(string)
  nullable    = false
  description = "List of Action Group IDs"
}

variable "log_analytics_workspace_id" {
  type        = string
  nullable    = false
  description = "Full resource ID of the Log Analytics Workspace"
}

###############################################################
# POLICY - BACKUP
###############################################################
variable "backup_exclusion_tags" {
  type        = list(string)
  default     = ["NoBackup"]
  description = "Tags to exclude from VM Backup policy"
}

variable "private_dns_zone_resource_group_name" {
  type        = string
  default     = ""
  description = "Resource group for private DNS zones"
}
