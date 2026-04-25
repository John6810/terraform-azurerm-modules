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

###############################################################
# RESOURCE: Registration Info — auto-rotating token
#
# time_rotating advances whenever `terraform apply` runs after the
# rotation_hours window has elapsed. The dependent registration_info
# resource is then replace-triggered, which generates a fresh token
# with a new expiration_date.
#
# Operationally: schedule a CI apply at least once per rotation
# period (e.g. nightly when registration_expiration_hours > 24) so
# new session hosts always find a valid token to register against.
###############################################################
resource "time_rotating" "registration_token" {
  count = var.create_registration_info ? 1 : 0

  rotation_hours = var.registration_expiration_hours
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "this" {
  count = var.create_registration_info ? 1 : 0

  hostpool_id     = azurerm_virtual_desktop_host_pool.this.id
  expiration_date = time_rotating.registration_token[0].rotation_rfc3339

  lifecycle {
    replace_triggered_by = [time_rotating.registration_token[0]]
  }
}
