###############################################################
# MODULE: NetworkWatcher - Main
# Description: Azure Network Watcher with optional inline Resource Group
###############################################################

resource "time_static" "time" {}

###############################################################
# Naming Convention
# Convention: nw-{subscription_acronym}-{environment}-{region_code}-{workload}
# Example:    nw-api-prod-gwc-01
###############################################################
locals {
  computed_name       = var.workload != null ? "nw-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.workload}" : "nw-${var.subscription_acronym}-${var.environment}-${var.region_code}"
  name                = var.name != null ? var.name : local.computed_name
  resource_group_name = var.create_resource_group ? azurerm_resource_group.this[0].name : var.resource_group_name
}

###############################################################
# RESOURCE: Inline Resource Group (optional)
###############################################################
resource "azurerm_resource_group" "this" {
  count    = var.create_resource_group ? 1 : 0
  name     = "rg-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.resource_group_workload}"
  location = var.location

  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}

###############################################################
# RESOURCE: Network Watcher
###############################################################
resource "azurerm_network_watcher" "this" {
  name                = local.name
  location            = var.location
  resource_group_name = local.resource_group_name

  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}

###############################################################
# RESOURCE: Management Lock
###############################################################
resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_network_watcher.this.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}
