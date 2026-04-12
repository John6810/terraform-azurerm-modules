###############################################################
# Module Hsm - Azure Key Vault Managed HSM
###############################################################

resource "time_static" "time" {}

###############################################################
# Optional: Inline Resource Group Creation
###############################################################
resource "azurerm_resource_group" "this" {
  count    = var.create_resource_group ? 1 : 0
  name     = "rg-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.resource_group_workload}"
  location = var.location
  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}

data "azurerm_client_config" "current" {}

locals {
  resource_group_name = var.create_resource_group ? azurerm_resource_group.this[0].name : var.resource_group_name
  computed_name       = "hsm-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.workload}"
  name                = var.name != null ? var.name : local.computed_name
  identity_name       = "id-${var.subscription_acronym}-${var.environment}-${var.region_code}-hsm"
}

resource "azurerm_user_assigned_identity" "hsm" {
  name                = local.identity_name
  location            = var.location
  resource_group_name = local.resource_group_name

  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}

resource "azurerm_key_vault_managed_hardware_security_module" "this" {
  name                          = local.name
  resource_group_name           = local.resource_group_name
  location                      = var.location
  sku_name                      = var.sku_name
  purge_protection_enabled      = var.purge_protection_enabled
  soft_delete_retention_days    = var.soft_delete_retention_days
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  admin_object_ids              = length(var.admin_object_ids) > 0 ? var.admin_object_ids : [data.azurerm_client_config.current.object_id]
  public_network_access_enabled = var.private_endpoint_subnet_id != null ? false : var.public_network_access_enabled

  network_acls {
    bypass         = "AzureServices"
    default_action = var.private_endpoint_subnet_id != null ? "Deny" : "Allow"
  }

  tags = merge(
    var.tags,
    {
      CreatedOn = formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))
    }
  )
}

###############################################################
# Private Endpoint
###############################################################
resource "azurerm_private_endpoint" "this" {
  count = var.private_endpoint_subnet_id != null ? 1 : 0

  name                = "pep-${local.name}"
  location            = var.location
  resource_group_name = local.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "psc-${local.name}"
    private_connection_resource_id = azurerm_key_vault_managed_hardware_security_module.this.id
    subresource_names              = ["managedhsm"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = length(var.private_dns_zone_ids) > 0 ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = var.private_dns_zone_ids
    }
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
