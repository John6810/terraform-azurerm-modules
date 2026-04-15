###############################################################
# tflint lint-time values only — NOT used at runtime.
# The caller always provides these; this file exists solely so
# tflint can evaluate `local.computed_name` to validate the
# azurerm_storage_account_invalid_name rule.
###############################################################
subscription_acronym = "api"
environment          = "prod"
region_code          = "gwc"
workload             = "lint"
location             = "germanywestcentral"
resource_group_name  = "rg-lint"
