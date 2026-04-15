###############################################################
# MODULE: LogAnalyticsAlerts - Variables
###############################################################

variable "subscription_acronym" {
  description = "Subscription acronym (e.g. mgm, con, api)."
  type        = string
}

variable "environment" {
  description = "Environment code (prod / nprd)."
  type        = string
}

variable "region_code" {
  description = "Region code (e.g. gwc)."
  type        = string
}

variable "location" {
  description = "Azure region (e.g. germanywestcentral)."
  type        = string
}

variable "workload" {
  description = "Workload name (used for tagging / conventions). Not part of alert naming."
  type        = string
  default     = "custom-alerts"
}

variable "resource_group_name" {
  description = "Resource group that will hold the alert rules."
  type        = string
}

variable "law_id" {
  description = "Resource ID of the Log Analytics Workspace the KQL queries run against."
  type        = string
}

variable "custom_tables" {
  description = <<-EOT
    Custom Log Analytics tables (`*_CL`) to create for alert queries that do not have a source table yet.
    Key = table name WITHOUT the `_CL` suffix (Azure appends it automatically). Must match `Log-Type`
    header used by the ingesting clients (Data Collector API).

    Fields:
    - `columns`          - (Required) Map of column name → Azure LAW column type (string/int/long/real/boolean/dateTime/guid/dynamic).
    - `retention_days`   - (Optional) Retention in days. Default inherits from workspace.
    - `total_retention_days` - (Optional) Total retention (archive included). Default inherits.
    - `plan`             - (Optional) Analytics | Basic. Default Analytics.
  EOT
  type = map(object({
    columns              = map(string)
    retention_days       = optional(number)
    total_retention_days = optional(number)
    plan                 = optional(string, "Analytics")
  }))
  default  = {}
  nullable = false
}

variable "action_group_ids" {
  description = "List of Action Group IDs fired when any alert triggers. Can be overridden per-alert."
  type        = list(string)
  default     = []
}

variable "alerts" {
  description = <<-EOT
    Map of KQL-based Log Analytics alerts (azurerm_monitor_scheduled_query_rules_alert_v2).
    Key = short alert identifier (used to build the resource name: `alert-{acr}-{env}-{region}-{key}`).

    Fields:
    - `display_name`            - (Optional) Human-readable name shown in the portal. Defaults to key.
    - `description`             - (Optional) Free text.
    - `kql`                     - (Required) KQL query producing the rows to count.
    - `severity`                - (Optional, 0-4) 0=Critical, 1=Error, 2=Warning, 3=Informational, 4=Verbose. Default 2.
    - `evaluation_frequency`    - (Optional ISO8601) How often the query runs. Default PT5M.
    - `window_duration`         - (Optional ISO8601) Lookback window. Default PT15M.
    - `threshold`               - (Optional number) Threshold to compare against. Default 0.
    - `operator`                - (Optional) GreaterThan, GreaterThanOrEqual, Equal, LessThan, LessThanOrEqual. Default GreaterThan.
    - `time_aggregation_method` - (Optional) Count, Average, Minimum, Maximum, Total. Default Count.
    - `metric_measure_column`   - (Optional) Column to aggregate (required when time_aggregation_method != Count).
    - `failing_periods`         - (Optional) number_of_evaluation_periods / minimum_failing_periods_to_trigger_alert. Default 1/1.
    - `auto_mitigation_enabled` - (Optional bool) Default false (alerts stay active until resolved manually).
    - `enabled`                 - (Optional bool) Default true.
    - `action_group_ids`        - (Optional list) Override default Action Groups for this alert.
    - `custom_properties`       - (Optional map) Passed to alert payload.
  EOT
  type = map(object({
    display_name            = optional(string)
    description             = optional(string, "")
    kql                     = string
    severity                = optional(number, 2)
    evaluation_frequency    = optional(string, "PT5M")
    window_duration         = optional(string, "PT15M")
    threshold               = optional(number, 0)
    operator                = optional(string, "GreaterThan")
    time_aggregation_method = optional(string, "Count")
    metric_measure_column   = optional(string)
    failing_periods = optional(object({
      number_of_evaluation_periods             = number
      minimum_failing_periods_to_trigger_alert = number
    }), { number_of_evaluation_periods = 1, minimum_failing_periods_to_trigger_alert = 1 })
    auto_mitigation_enabled = optional(bool, false)
    enabled                 = optional(bool, true)
    action_group_ids        = optional(list(string))
    custom_properties       = optional(map(string), {})
  }))
  nullable = false
}

variable "tags" {
  description = "Tags applied to every alert rule."
  type        = map(string)
  default     = {}
}
