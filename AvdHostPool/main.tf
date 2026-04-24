###############################################################
# MODULE: AvdHostPool - Main
# Description: Azure Virtual Desktop host pool
###############################################################

resource "time_static" "time" {}

###############################################################
# Naming Convention
# Convention: vdpool-{subscription_acronym}-{environment}-{region_code}-{workload}
# Example:    vdpool-avd-nprd-gwc-pooled
###############################################################
locals {
  computed_name = "vdpool-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.workload}"
  name          = var.name != null ? var.name : local.computed_name
}

###############################################################
# RESOURCE: Host Pool
###############################################################
resource "azurerm_virtual_desktop_host_pool" "this" {
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name

  type                     = var.type
  load_balancer_type       = var.load_balancer_type
  maximum_sessions_allowed = var.type == "Pooled" ? var.maximum_sessions_allowed : null
  preferred_app_group_type = var.preferred_app_group_type
  start_vm_on_connect      = var.start_vm_on_connect
  validate_environment     = var.validate_environment
  public_network_access    = var.public_network_access

  friendly_name         = var.friendly_name
  description           = var.description
  custom_rdp_properties = var.custom_rdp_properties

  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}
