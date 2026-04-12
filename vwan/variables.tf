# ═══════════════════════════════════════════════════════════════════════════════
# VARIABLES — Virtual WAN Core
# ═══════════════════════════════════════════════════════════════════════════════

variable "name" {
  description = "Name of the Virtual WAN"
  type        = string
  nullable    = false
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
  nullable    = false
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  nullable    = false
}

variable "type" {
  description = "Type of Virtual WAN (Basic or Standard)"
  type        = string
  default     = "Standard"
  nullable    = false

  validation {
    condition     = contains(["Basic", "Standard"], var.type)
    error_message = "Type must be either 'Basic' or 'Standard'."
  }
}

variable "disable_vpn_encryption" {
  description = "Whether to disable VPN encryption for the Virtual WAN"
  type        = bool
  default     = false
}

variable "allow_branch_to_branch_traffic" {
  description = "Whether to allow branch-to-branch traffic through the Virtual WAN"
  type        = bool
  default     = true
}

variable "office365_local_breakout_category" {
  description = "Office 365 local breakout category (None, Optimize, OptimizeAndAllow, All)"
  type        = string
  default     = "None"
  nullable    = false

  validation {
    condition     = contains(["None", "Optimize", "OptimizeAndAllow", "All"], var.office365_local_breakout_category)
    error_message = "Office 365 local breakout category must be one of: None, Optimize, OptimizeAndAllow, All."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
