###############################################################
# MODULE: NatGateway - Main
# Description: Azure NAT Gateway StandardV2 (zone-redundant)
#              with associated Public IP via azapi provider
#              (azurerm does not yet support StandardV2 SKU)
###############################################################

resource "time_static" "time" {}

###############################################################
# Naming Convention
# Convention: ng-{subscription_acronym}-{environment}-{region_code}-{workload}
# Example:    ng-con-prod-gwc-untrust
###############################################################
locals {
  computed_name = "ng-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.workload}"
  name          = var.name != null ? var.name : local.computed_name

  common_tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}

###############################################################
# RESOURCE: Public IP (zone-redundant, StandardV2 SKU)
###############################################################
resource "azapi_resource" "public_ip" {
  type      = "Microsoft.Network/publicIPAddresses@2025-03-01"
  name      = "pip-${local.name}"
  location  = var.location
  parent_id = var.resource_group_id
  tags      = local.common_tags

  body = {
    properties = {
      publicIPAllocationMethod = "Static"
      publicIPAddressVersion   = "IPv4"
    }
    sku = {
      name = "StandardV2"
      tier = "Regional"
    }
    zones = var.zones
  }

  response_export_values = ["properties.ipAddress"]
}

###############################################################
# RESOURCE: NAT Gateway (StandardV2, zone-redundant)
###############################################################
resource "azapi_resource" "nat_gateway" {
  type      = "Microsoft.Network/natGateways@2025-03-01"
  name      = local.name
  location  = var.location
  parent_id = var.resource_group_id
  tags      = local.common_tags

  body = {
    properties = {
      idleTimeoutInMinutes = var.idle_timeout_in_minutes
      publicIpAddresses = [
        {
          id = azapi_resource.public_ip.id
        }
      ]
    }
    sku = {
      name = "StandardV2"
    }
    zones = var.zones
  }
}
