###############################################################
# MODULE: AvdScalingPlan - Variables
# Naming: vdscaling-{sub_acronym}-{environment}-{region_code}-{workload}
###############################################################

variable "name" {
  type        = string
  default     = null
  description = "Explicit scaling plan name. If null, computed automatically."
}

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
  description = "Workload suffix (e.g. pooled)."
  default     = "pooled"
}

###############################################################
# REQUIRED
###############################################################
variable "location" {
  type        = string
  description = "Must match the host pool region."
  nullable    = false
}

variable "resource_group_name" {
  type     = string
  nullable = false
}

variable "time_zone" {
  type        = string
  description = "IANA or Windows time zone (e.g. 'W. Europe Standard Time'). Drives schedule times."
  default     = "W. Europe Standard Time"
}

variable "friendly_name" {
  type    = string
  default = null
}

variable "description" {
  type    = string
  default = null
}

variable "exclusion_tag" {
  type        = string
  description = "Tag name on session hosts to exclude from autoscale (e.g. 'excludeFromScaling')."
  default     = null
}

###############################################################
# SCHEDULES
###############################################################
variable "schedules" {
  description = <<-EOT
  Map of scaling plan schedules. For Pooled host pools:

  - `days_of_week`                         - (Required) List: Monday..Sunday
  - `ramp_up_start_time`                   - (Required) "HH:MM"
  - `ramp_up_load_balancing_algorithm`     - (Required) BreadthFirst | DepthFirst
  - `ramp_up_minimum_hosts_percent`        - (Required) 0-100
  - `ramp_up_capacity_threshold_percent`   - (Required) 1-100
  - `peak_start_time`                      - (Required) "HH:MM"
  - `peak_load_balancing_algorithm`        - (Required) BreadthFirst | DepthFirst
  - `ramp_down_start_time`                 - (Required) "HH:MM"
  - `ramp_down_load_balancing_algorithm`   - (Required) BreadthFirst | DepthFirst
  - `ramp_down_minimum_hosts_percent`      - (Required) 0-100
  - `ramp_down_capacity_threshold_percent` - (Required) 1-100
  - `ramp_down_force_logoff_users`         - (Required) bool
  - `ramp_down_wait_time_minutes`          - (Required) minutes before forced logoff
  - `ramp_down_notification_message`       - (Required) shown to users before logoff
  - `ramp_down_stop_hosts_when`            - (Required) ZeroActiveSessions | ZeroSessions
  - `off_peak_start_time`                  - (Required) "HH:MM"
  - `off_peak_load_balancing_algorithm`    - (Required) BreadthFirst | DepthFirst
  EOT
  type = map(object({
    days_of_week                         = list(string)
    ramp_up_start_time                   = string
    ramp_up_load_balancing_algorithm     = string
    ramp_up_minimum_hosts_percent        = number
    ramp_up_capacity_threshold_percent   = number
    peak_start_time                      = string
    peak_load_balancing_algorithm        = string
    ramp_down_start_time                 = string
    ramp_down_load_balancing_algorithm   = string
    ramp_down_minimum_hosts_percent      = number
    ramp_down_capacity_threshold_percent = number
    ramp_down_force_logoff_users         = bool
    ramp_down_wait_time_minutes          = number
    ramp_down_notification_message       = string
    ramp_down_stop_hosts_when            = string
    off_peak_start_time                  = string
    off_peak_load_balancing_algorithm    = string
  }))
  nullable = false

  validation {
    condition = alltrue([
      for s in var.schedules : alltrue([
        for d in s.days_of_week :
        contains(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], d)
      ])
    ])
    error_message = "days_of_week entries must be PascalCase (Monday, Tuesday, … Sunday). Azure rejects lowercase or abbreviated forms."
  }

  validation {
    condition = alltrue([
      for s in var.schedules :
      can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", s.ramp_up_start_time)) &&
      can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", s.peak_start_time)) &&
      can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", s.ramp_down_start_time)) &&
      can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", s.off_peak_start_time))
    ])
    error_message = "ramp_up_start_time, peak_start_time, ramp_down_start_time, off_peak_start_time must be HH:MM (00:00-23:59)."
  }

  validation {
    condition = alltrue([
      for s in var.schedules :
      s.ramp_up_minimum_hosts_percent >= 0 && s.ramp_up_minimum_hosts_percent <= 100 &&
      s.ramp_up_capacity_threshold_percent >= 1 && s.ramp_up_capacity_threshold_percent <= 100 &&
      s.ramp_down_minimum_hosts_percent >= 0 && s.ramp_down_minimum_hosts_percent <= 100 &&
      s.ramp_down_capacity_threshold_percent >= 1 && s.ramp_down_capacity_threshold_percent <= 100
    ])
    error_message = "Percent fields out of range — minimum_hosts_percent must be 0-100; capacity_threshold_percent must be 1-100."
  }

  validation {
    condition = alltrue([
      for s in var.schedules :
      contains(["BreadthFirst", "DepthFirst"], s.ramp_up_load_balancing_algorithm) &&
      contains(["BreadthFirst", "DepthFirst"], s.peak_load_balancing_algorithm) &&
      contains(["BreadthFirst", "DepthFirst"], s.ramp_down_load_balancing_algorithm) &&
      contains(["BreadthFirst", "DepthFirst"], s.off_peak_load_balancing_algorithm)
    ])
    error_message = "load_balancing_algorithm fields must be either BreadthFirst or DepthFirst (PascalCase)."
  }

  validation {
    condition = alltrue([
      for s in var.schedules :
      contains(["ZeroActiveSessions", "ZeroSessions"], s.ramp_down_stop_hosts_when)
    ])
    error_message = "ramp_down_stop_hosts_when must be either ZeroActiveSessions or ZeroSessions (PascalCase)."
  }
}

###############################################################
# HOST POOL ASSOCIATIONS
###############################################################
variable "host_pool_associations" {
  description = "Map key => { hostpool_id, scaling_plan_enabled }"
  type = map(object({
    hostpool_id          = string
    scaling_plan_enabled = optional(bool, true)
  }))
  nullable = false
}

###############################################################
# TAGS
###############################################################
variable "tags" {
  type    = map(string)
  default = {}
}
