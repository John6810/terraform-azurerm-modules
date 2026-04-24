###############################################################
# MODULE: AvdSessionHost - Main
# POC-sized: NIC + VM + 3 extensions (Entra join, AVD DSC, FSLogix)
###############################################################

locals {
  prefix        = "${var.subscription_acronym}-${var.environment}-${var.region_code}"
  computer_name = var.computer_name_prefix != null ? var.computer_name_prefix : "avd${var.environment}${var.region_code}"

  vms = {
    for i in range(var.vm_count) : format("%02d", i + 1) => {
      index         = i
      suffix        = format("%02d", i + 1)
      vm_name       = "vm-${local.prefix}-${var.workload}-${format("%02d", i + 1)}"
      computer_name = "${local.computer_name}${format("%02d", i + 1)}"
      nic_name      = "nic-${local.prefix}-${var.workload}-${format("%02d", i + 1)}"
      zone          = length(var.availability_zones) > 0 ? element(var.availability_zones, i) : null
    }
  }

  # FSLogix registry setup + Entra Kerberos (one-shot PowerShell)
  fslogix_command = join(" ; ", [
    "New-Item -Path 'HKLM:\\SOFTWARE\\FSLogix\\Profiles' -Force | Out-Null",
    "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\FSLogix\\Profiles' -Name 'Enabled' -Value 1 -Type DWord",
    "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\FSLogix\\Profiles' -Name 'VHDLocations' -Value '${var.fslogix_vhd_location}' -Type MultiString",
    "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\FSLogix\\Profiles' -Name 'FlipFlopProfileDirectoryName' -Value 1 -Type DWord",
    "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\FSLogix\\Profiles' -Name 'DeleteLocalProfileWhenVHDShouldApply' -Value 1 -Type DWord",
    "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\FSLogix\\Profiles' -Name 'SizeInMBs' -Value ${var.fslogix_profile_size_mb} -Type DWord",
    "New-Item -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Lsa\\Kerberos\\Parameters' -Force | Out-Null",
    "Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Lsa\\Kerberos\\Parameters' -Name 'CloudKerberosTicketRetrievalEnabled' -Value 1 -Type DWord",
    "New-Item -Path 'HKLM:\\Software\\Policies\\Microsoft\\AzureADAccount' -Force | Out-Null",
    "Set-ItemProperty -Path 'HKLM:\\Software\\Policies\\Microsoft\\AzureADAccount' -Name 'LoadCredKeyFromProfile' -Value 1 -Type DWord"
  ])
}

###############################################################
# DATA: Admin password from Key Vault
###############################################################
data "azurerm_key_vault_secret" "admin_password" {
  name         = var.admin_password_secret_name
  key_vault_id = var.admin_password_kv_id
}

###############################################################
# RESOURCE: NICs (one per VM)
###############################################################
resource "azurerm_network_interface" "this" {
  for_each = local.vms

  name                = each.value.nic_name
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "ipc-default"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

###############################################################
# RESOURCE: Windows Session Host VMs
###############################################################
resource "azurerm_windows_virtual_machine" "this" {
  for_each = local.vms

  name                = each.value.vm_name
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  zone                = each.value.zone

  computer_name  = each.value.computer_name
  admin_username = var.admin_username
  admin_password = data.azurerm_key_vault_secret.admin_password.value

  network_interface_ids = [azurerm_network_interface.this[each.key].id]

  # Trusted Launch (vTPM + Secure Boot) — MS recommended for Win11 + AVD
  secure_boot_enabled = var.enable_trusted_launch
  vtpm_enabled        = var.enable_trusted_launch

  os_disk {
    name = "osdisk-${each.value.vm_name}"
    # Ephemeral OS requires caching=ReadOnly (Azure constraint)
    caching              = var.os_disk.ephemeral ? "ReadOnly" : var.os_disk.caching
    storage_account_type = var.os_disk.storage_account_type
    disk_size_gb         = var.os_disk.disk_size_gb

    dynamic "diff_disk_settings" {
      for_each = var.os_disk.ephemeral ? [1] : []
      content {
        option    = "Local"
        placement = "ResourceDisk"
      }
    }
  }

  source_image_reference {
    publisher = var.image.publisher
    offer     = var.image.offer
    sku       = var.image.sku
    version   = var.image.version
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      admin_password, # Password rotated out-of-band via az vm reset command
      tags["CreatedOn"],
    ]
  }
}

###############################################################
# RESOURCE: VM Extension — Entra ID Join (AADLoginForWindows)
###############################################################
resource "azurerm_virtual_machine_extension" "entra_join" {
  for_each = local.vms

  name                       = "AADLoginForWindows"
  virtual_machine_id         = azurerm_windows_virtual_machine.this[each.key].id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "2.0"
  auto_upgrade_minor_version = true

  tags = var.tags
}

###############################################################
# RESOURCE: VM Extension — AVD DSC (session host registration)
###############################################################
resource "azurerm_virtual_machine_extension" "avd_dsc" {
  for_each = local.vms

  name                       = "AVDDscExtension"
  virtual_machine_id         = azurerm_windows_virtual_machine.this[each.key].id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.83"
  auto_upgrade_minor_version = true

  # Microsoft's AddSessionHost DSC expects a pscredential-style token.
  # Public side uses PrivateSettingsRef to reference the secret in protected settings.
  settings = jsonencode({
    modulesUrl            = var.avd_dsc_artifact_url
    configurationFunction = "Configuration.ps1\\AddSessionHost"
    properties = {
      hostPoolName = var.hostpool_name
      registrationInfoTokenCredential = {
        UserName = "PLACEHOLDER_DO_NOT_USE"
        Password = "PrivateSettingsRef:RegistrationInfoToken"
      }
      aadJoin = true
    }
  })

  protected_settings = jsonencode({
    Items = {
      RegistrationInfoToken = var.hostpool_registration_token
    }
  })

  depends_on = [azurerm_virtual_machine_extension.entra_join]
  tags       = var.tags
}

###############################################################
# RESOURCE: VM Extension — FSLogix Registry (CustomScriptExtension)
###############################################################
resource "azurerm_virtual_machine_extension" "fslogix" {
  for_each = local.vms

  name                       = "FslogixConfig"
  virtual_machine_id         = azurerm_windows_virtual_machine.this[each.key].id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  protected_settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Bypass -NoProfile -Command \"${local.fslogix_command}\""
  })

  depends_on = [azurerm_virtual_machine_extension.avd_dsc]
  tags       = var.tags
}
