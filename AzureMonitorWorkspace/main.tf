###############################################################
# MODULE: AzureMonitorWorkspace - Main
# Description: Azure Monitor Workspace (Managed Prometheus)
#              with optional Private Endpoint
###############################################################

resource "time_static" "time" {}

###############################################################
# Naming Convention
# Convention: amw-{subscription_acronym}-{environment}-{region_code}-{workload}
# Example:    amw-mgm-prod-gwc-01
###############################################################
locals {
  prefix        = "${var.subscription_acronym}-${var.environment}-${var.region_code}"
  computed_name = "amw-${local.prefix}-${var.workload}"
  name          = var.name != null ? var.name : local.computed_name
}

###############################################################
# RESOURCE: Azure Monitor Workspace
###############################################################
resource "azurerm_monitor_workspace" "this" {
  name                          = local.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  public_network_access_enabled = var.public_network_access_enabled

  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}

###############################################################
# RESOURCE: Private Endpoint (prometheusMetrics)
###############################################################
resource "azurerm_private_endpoint" "this" {
  count = var.subnet_id != null ? 1 : 0

  name                = "pep-${local.prefix}-amw-${var.workload}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-pep-${local.prefix}-amw-${var.workload}"
    private_connection_resource_id = azurerm_monitor_workspace.this.id
    subresource_names              = ["prometheusMetrics"]
    is_manual_connection           = false
  }

  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )

  lifecycle {
    ignore_changes = [private_dns_zone_group]
  }
}
