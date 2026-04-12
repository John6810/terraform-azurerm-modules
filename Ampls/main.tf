###############################################################
# MODULE: Ampls - Main
# Description: Azure Monitor Private Link Scope with scoped
#              services and Private Endpoint
###############################################################

resource "time_static" "time" {}

locals {
  common_tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}

###############################################################
# Azure Monitor Private Link Scope
###############################################################
resource "azurerm_monitor_private_link_scope" "this" {
  name                  = var.ampls_name
  resource_group_name   = var.resource_group_name
  ingestion_access_mode = var.ingestion_access_mode
  query_access_mode     = var.query_access_mode
  tags                  = local.common_tags
}

###############################################################
# Scoped Services (LAW, Automation Account, etc.)
###############################################################
resource "azurerm_monitor_private_link_scoped_service" "this" {
  for_each = var.scoped_services

  name                = "ampls-${each.key}"
  resource_group_name = var.resource_group_name
  scope_name          = azurerm_monitor_private_link_scope.this.name
  linked_resource_id  = each.value.resource_id
}

###############################################################
# Private Endpoint for AMPLS
###############################################################
resource "azurerm_private_endpoint" "this" {
  name                = "pep-${var.ampls_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  depends_on = [azurerm_monitor_private_link_scoped_service.this]

  private_service_connection {
    name                           = "psc-${var.ampls_name}"
    private_connection_resource_id = azurerm_monitor_private_link_scope.this.id
    subresource_names              = ["azuremonitor"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = var.private_dns_zone_ids
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [private_dns_zone_group]
  }
}
