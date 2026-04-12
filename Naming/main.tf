###############################################################
# MODULE: Naming - Main
# Description: Azure resource naming via official Azure module
#              + custom naming for Palo Alto and other resources
###############################################################

###############################################################
# Azure Official Naming Module
###############################################################
module "azure_naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.4.3"

  prefix        = var.prefix
  suffix        = var.suffix
  unique-seed   = var.unique_seed
  unique-length = var.unique_length
}

###############################################################
# Custom Naming Logic
###############################################################
locals {
  prefix      = length(var.prefix) > 0 ? "${join("-", var.prefix)}-" : ""
  suffix      = length(var.suffix) > 0 ? "-${join("-", var.suffix)}" : ""
  environment = var.environment != null && var.environment != "" ? "-${var.environment}" : ""
  region      = var.region != null && var.region != "" ? "-${var.region}" : ""

  custom_resource_types = merge(
    {
      palo_alto_vm_series          = "palofw"
      palo_alto_management_profile = "paloprf"
      palo_alto_interface          = "paloif"
      palo_alto_zone               = "palozone"
      palo_alto_virtual_router     = "palovr"
      palo_alto_security_policy    = "palopol"
      route_table_route            = "route"
      nsg_security_rule            = "nsgr"
      subnet_nsg_association       = "snsga"
      subnet_rt_association        = "srta"
      custom_vm                    = "vm"
      custom_nic                   = "nic"
      custom_disk                  = "disk"
      custom_pip                   = "pip"
    },
    var.custom_resource_types
  )

  custom_names = {
    for type, short_name in local.custom_resource_types :
    type => "${local.prefix}${short_name}${local.environment}${local.region}${local.suffix}"
  }
}

###############################################################
# Name Sanitization
###############################################################
locals {
  # General: lowercase, alphanumeric + hyphens, max 63 chars
  sanitize_name = {
    for k, v in local.custom_names :
    k => lower(substr(replace(v, "/[^a-zA-Z0-9-]/", ""), 0, 63))
  }

  # Storage: lowercase, alphanumeric only, max 24 chars
  sanitize_storage_name = {
    for k, v in local.custom_names :
    k => lower(substr(replace(v, "/[^a-zA-Z0-9]/", ""), 0, 24))
  }
}

###############################################################
# Combined Names
###############################################################
locals {
  all_names = merge(
    {
      resource_group          = module.azure_naming.resource_group.name
      virtual_network         = module.azure_naming.virtual_network.name
      subnet                  = module.azure_naming.subnet.name
      network_security_group  = module.azure_naming.network_security_group.name
      route_table             = module.azure_naming.route_table.name
      public_ip               = module.azure_naming.public_ip.name
      network_interface       = module.azure_naming.network_interface.name
      virtual_machine         = module.azure_naming.virtual_machine.name
      storage_account         = module.azure_naming.storage_account.name
      key_vault               = module.azure_naming.key_vault.name
      log_analytics_workspace = module.azure_naming.log_analytics_workspace.name
      availability_set        = module.azure_naming.availability_set.name
      managed_disk            = module.azure_naming.managed_disk.name
      load_balancer           = module.azure_naming.lb.name
      application_gateway     = module.azure_naming.application_gateway.name
    },
    local.sanitize_name
  )

  build_name = {
    for type in keys(local.all_names) :
    type => {
      for name_suffix in var.name_suffixes :
      name_suffix => "${local.all_names[type]}-${name_suffix}"
    }
  }
}
