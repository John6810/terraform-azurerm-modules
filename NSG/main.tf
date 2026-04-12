###############################################################
# MODULE: NSG - Main
# Description: Creates multiple Azure Network Security Groups
# Naming: nsg-{subscription_acronym}-{environment}-{region_code}-{key}
###############################################################

resource "time_static" "time" {}

###############################################################
# Naming Convention
###############################################################
locals {
  nsg_map = { for k, v in var.nsgs : k => {
    name  = "nsg-${var.subscription_acronym}-${var.environment}-${var.region_code}-${k}"
    rules = v
  } }
}

###############################################################
# RESOURCE: Network Security Groups
###############################################################
resource "azurerm_network_security_group" "this" {
  for_each = local.nsg_map

  name                = each.value.name
  location            = var.location
  resource_group_name = var.resource_group_name

  dynamic "security_rule" {
    for_each = each.value.rules
    content {
      name      = security_rule.value.name
      priority  = security_rule.value.priority
      direction = security_rule.value.direction
      access    = security_rule.value.access
      protocol  = security_rule.value.protocol

      source_port_range      = security_rule.value.source_port_range
      destination_port_range = security_rule.value.destination_port_range

      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix

      source_port_ranges      = security_rule.value.source_port_ranges
      destination_port_ranges = security_rule.value.destination_port_ranges

      source_address_prefixes      = security_rule.value.source_address_prefixes
      destination_address_prefixes = security_rule.value.destination_address_prefixes

      source_application_security_group_ids      = security_rule.value.source_application_security_group_ids
      destination_application_security_group_ids = security_rule.value.destination_application_security_group_ids

      description = security_rule.value.description
    }
  }

  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}
