###############################################################
# MODULE: AvdApplicationGroup - Main
###############################################################

resource "time_static" "time" {}

locals {
  computed_name = "vdag-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.workload}"
  name          = var.name != null ? var.name : local.computed_name
}

resource "azurerm_virtual_desktop_application_group" "this" {
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name

  type         = var.type
  host_pool_id = var.host_pool_id

  friendly_name = var.friendly_name
  description   = var.description

  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}

###############################################################
# RESOURCE: Workspace association (optional)
###############################################################
resource "azurerm_virtual_desktop_workspace_application_group_association" "this" {
  count = var.workspace_id != null ? 1 : 0

  workspace_id         = var.workspace_id
  application_group_id = azurerm_virtual_desktop_application_group.this.id
}
