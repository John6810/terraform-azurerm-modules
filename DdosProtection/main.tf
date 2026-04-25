###############################################################
# MODULE: DdosProtection - Main
# Description: Azure DDoS Protection Plan
###############################################################

resource "time_static" "time" {}

###############################################################
# Naming Convention
# Convention: ddos-{subscription_acronym}-{environment}-{region_code}-{workload}
# Example:    ddos-con-prod-gwc-network
###############################################################
locals {
  computed_name = "ddos-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.workload}"
  name          = var.name != null ? var.name : local.computed_name
}

###############################################################
# RESOURCE: DDoS Protection Plan
###############################################################
resource "azurerm_network_ddos_protection_plan" "this" {
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )

  lifecycle {
    prevent_destroy = true
  }
}

###############################################################
# RESOURCE: Management Lock
###############################################################
resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_network_ddos_protection_plan.this.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}
