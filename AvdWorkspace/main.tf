###############################################################
# MODULE: AvdWorkspace - Main
###############################################################

resource "time_static" "time" {}

locals {
  computed_name = "vdws-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.workload}"
  name          = var.name != null ? var.name : local.computed_name
}

resource "azurerm_virtual_desktop_workspace" "this" {
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name

  friendly_name                 = var.friendly_name
  description                   = var.description
  public_network_access_enabled = var.public_network_access_enabled

  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}
