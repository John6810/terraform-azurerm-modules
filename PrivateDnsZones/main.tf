###############################################################
# MODULE: PrivateDnsZones - Main
# Description: Dedicated RG + all Azure Private Link DNS Zones
#              via the AVM pattern module
###############################################################

resource "time_static" "time" {}

locals {
  rg_name = "rg-${var.subscription_acronym}-${var.environment}-${var.region_code}-plink-dns"
}

###############################################################
# RESOURCE: Resource Group
###############################################################
resource "azurerm_resource_group" "this" {
  name     = local.rg_name
  location = var.location

  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}

###############################################################
# MODULE: AVM — Private Link Private DNS Zones
###############################################################
module "private_dns_zones" {
  source  = "Azure/avm-ptn-network-private-link-private-dns-zones/azurerm"
  version = "~> 0.23"

  location         = var.location
  parent_id        = azurerm_resource_group.this.id
  enable_telemetry = false

  virtual_network_link_default_virtual_networks = var.virtual_network_links

  tags = var.tags
}
