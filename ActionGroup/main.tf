###############################################################
# MODULE: ActionGroup - Main
# Description: Azure Monitor Action Group with email and push receivers
###############################################################

resource "time_static" "time" {}

###############################################################
# Naming Convention
# Convention: ag-{subscription_acronym}-{environment}-{region_code}-{workload}
# Example:    ag-mgm-nprd-gwc-ama
###############################################################
locals {
  computed_name = "ag-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.workload}"
  name          = var.name != null ? var.name : local.computed_name
}

###############################################################
# RESOURCE: Action Group
###############################################################
resource "azurerm_monitor_action_group" "this" {
  name                = local.name
  location            = "global"
  resource_group_name = var.resource_group_name
  short_name          = var.short_name

  dynamic "email_receiver" {
    for_each = var.email_addresses
    content {
      name                    = replace(email_receiver.value, "@", "-at-")
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }

  dynamic "azure_app_push_receiver" {
    for_each = var.push_email_addresses
    content {
      name          = "${replace(azure_app_push_receiver.value, "@", "-at-")}-app"
      email_address = azure_app_push_receiver.value
    }
  }

  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}
