###############################################################
# Admin Password — auto-generated + stored in Key Vault
###############################################################
resource "random_password" "admin" {
  length           = 24
  special          = true
  override_special = "!@#$%^&*"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "azurerm_key_vault_secret" "admin_password" {
  count = var.enable_disk_encryption ? 1 : 0

  name            = "${var.workload}-admin-password"
  value           = random_password.admin.result
  key_vault_id    = azurerm_key_vault.this[0].id
  content_type    = "text/plain"
  expiration_date = timeadd(time_static.time.rfc3339, "2160h") # 90 days

  lifecycle {
    ignore_changes = [expiration_date, value]
  }

  depends_on = [azurerm_role_assignment.kv_admin]
}

###############################################################
# NICs — Management (NIC 0, primary) — access via vWAN, no PIP
###############################################################
resource "azurerm_network_interface" "mgmt" {
  for_each = var.firewalls

  name                           = "nic-${local.prefix}-fw-${each.key}-mgmt"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.this.name
  accelerated_networking_enabled = false # Must be false for PAN-OS management interface
  ip_forwarding_enabled          = false # Management NIC must not forward traffic

  ip_configuration {
    name                          = "ipconfig-mgmt"
    subnet_id                     = var.subnet_mgmt_id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.mgmt_ip
  }

  tags = local.common_tags
}

###############################################################
# NICs — Untrust (NIC 1)
###############################################################
resource "azurerm_network_interface" "untrust" {
  for_each = var.firewalls

  name                           = "nic-${local.prefix}-fw-${each.key}-untrust"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.this.name
  ip_forwarding_enabled          = true
  accelerated_networking_enabled = var.accelerated_networking

  ip_configuration {
    name                          = "ipconfig-untrust"
    subnet_id                     = var.subnet_untrust_id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.untrust_ip
  }

  tags = local.common_tags
}

###############################################################
# NICs — Trust (NIC 2)
###############################################################
resource "azurerm_network_interface" "trust" {
  for_each = var.firewalls

  name                           = "nic-${local.prefix}-fw-${each.key}-trust"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.this.name
  ip_forwarding_enabled          = true
  accelerated_networking_enabled = var.accelerated_networking

  ip_configuration {
    name                          = "ipconfig-trust"
    subnet_id                     = var.subnet_trust_id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.trust_ip
  }

  tags = local.common_tags
}

###############################################################
# Backend Pool Association — Trust NICs -> ILB
###############################################################
resource "azurerm_network_interface_backend_address_pool_association" "trust" {
  for_each = var.firewalls

  network_interface_id    = azurerm_network_interface.trust[each.key].id
  ip_configuration_name   = "ipconfig-trust"
  backend_address_pool_id = azurerm_lb_backend_address_pool.trust.id
}

###############################################################
# VM-Series Instances
###############################################################
resource "azurerm_linux_virtual_machine" "this" {
  for_each = var.firewalls

  name                = "fw-${local.prefix}-${each.key}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  size                = var.vm_size
  zone                = each.value.zone

  admin_username                  = var.admin_username
  admin_password                  = coalesce(var.admin_password, random_password.admin.result)
  disable_password_authentication = var.admin_ssh_public_key != null
  allow_extension_operations      = false

  network_interface_ids = [
    azurerm_network_interface.mgmt[each.key].id,
    azurerm_network_interface.untrust[each.key].id,
    azurerm_network_interface.trust[each.key].id,
  ]

  os_disk {
    name                   = "osdisk-fw-${local.prefix}-${each.key}"
    caching                = "ReadWrite"
    storage_account_type   = var.os_disk_storage_account_type
    disk_size_gb           = var.os_disk_size_gb
    disk_encryption_set_id = length(azurerm_disk_encryption_set.this) > 0 ? azurerm_disk_encryption_set.this[0].id : null
  }

  source_image_reference {
    publisher = var.vm_image.publisher
    offer     = var.vm_image.offer
    sku       = var.vm_image.sku
    version   = var.vm_image.version
  }

  plan {
    name      = var.vm_image.sku
    publisher = var.vm_image.publisher
    product   = var.vm_image.offer
  }

  dynamic "admin_ssh_key" {
    for_each = var.admin_ssh_public_key != null ? [1] : []
    content {
      username   = var.admin_username
      public_key = var.admin_ssh_public_key
    }
  }

  identity {
    type = "SystemAssigned"
  }

  # Boot diagnostics (for troubleshooting VM boot failures)
  dynamic "boot_diagnostics" {
    for_each = var.enable_boot_diagnostics ? [1] : []
    content {
      storage_account_uri = var.boot_diagnostics_storage_uri
    }
  }

  # Bootstrap via custom_data (semicolon-separated, PAN-OS format)
  custom_data = var.bootstrap_storage_account_name != null ? base64encode(join(";", compact([
    "storage-account=${var.bootstrap_storage_account_name}",
    "access-key=${var.bootstrap_storage_account_access_key}",
    "file-share=${var.bootstrap_share_name}",
    var.bootstrap_share_directory != null ? "share-directory=${var.bootstrap_share_directory}" : "",
  ]))) : null

  tags = local.common_tags

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      source_image_reference, # PAN-OS upgrades are managed manually (avoid VM replacement)
    ]
  }
}
