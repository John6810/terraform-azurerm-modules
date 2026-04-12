###############################################################
# Disk Encryption — Key Vault + Key + UAI + DES (1 per cluster)
###############################################################
# When enable_disk_encryption = true, creates:
#   1. Key Vault (RBAC, purge protection, disk encryption enabled)
#   2. RBAC deployer -> Key Vault Administrator
#   3. RSA 2048 key (auto-rotation 2 years)
#   4. User Assigned Identity
#   5. RBAC UAI -> Key Vault Crypto Service Encryption User
#   6. Disk Encryption Set (double encryption, auto-rotation)
#
# Note: KeyVault/KeyVault-Key/ManagedIdentity modules cannot be
#       called as child modules here because Terragrunt only copies
#       the PaloCluster folder into its cache — sibling modules are
#       not accessible. Resources are used directly, following the
#       same patterns as the existing modules.
###############################################################

data "azurerm_client_config" "current" {}

locals {
  # KV name max 24 chars — strip "palo-" from workload to shorten
  # palo-obew -> obew -> kv-con-prod-gwc-obew (20 chars)
  # palo-in   -> in   -> kv-con-prod-gwc-in   (18 chars)
  kv_workload = replace(var.workload, "palo-", "")
  kv_name     = "kv-${local.prefix}-${local.kv_workload}"
}

###############################################################
# Key Vault
###############################################################
resource "azurerm_key_vault" "this" {
  count = var.enable_disk_encryption ? 1 : 0

  name                = local.kv_name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled    = true
  enabled_for_disk_encryption   = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 90
  public_network_access_enabled = length(var.kv_allowed_ips) > 0

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = var.kv_allowed_ips
  }

  tags = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

###############################################################
# RBAC — Deployer -> Key Vault Administrator
###############################################################
resource "azurerm_role_assignment" "kv_admin" {
  count = var.enable_disk_encryption ? 1 : 0

  scope                = azurerm_key_vault.this[0].id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

###############################################################
# RSA 2048 Key (auto-rotation)
###############################################################
resource "azurerm_key_vault_key" "des" {
  count = var.enable_disk_encryption ? 1 : 0

  name         = "key-${var.workload}-disk-encryption"
  key_vault_id = azurerm_key_vault.this[0].id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["encrypt", "decrypt", "wrapKey", "unwrapKey"]

  rotation_policy {
    expire_after         = "P2Y"
    notify_before_expiry = "P30D"

    automatic {
      time_before_expiry = "P30D"
    }
  }

  depends_on = [azurerm_role_assignment.kv_admin]

  lifecycle {
    prevent_destroy = true
  }
}

###############################################################
# User Assigned Identity (for the DES)
###############################################################
resource "azurerm_user_assigned_identity" "des" {
  count = var.enable_disk_encryption ? 1 : 0

  name                = "id-${local.prefix}-${var.workload}-des"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name

  tags = local.common_tags
}

###############################################################
# RBAC — UAI -> Key Vault Crypto Service Encryption User
###############################################################
resource "azurerm_role_assignment" "des_crypto" {
  count = var.enable_disk_encryption ? 1 : 0

  scope                = azurerm_key_vault.this[0].id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.des[0].principal_id
}

###############################################################
# RBAC — Groups -> Key Vault Secrets User (read secrets)
###############################################################
resource "azurerm_role_assignment" "kv_secrets_reader" {
  for_each = var.enable_disk_encryption ? toset(var.kv_secrets_readers) : toset([])

  scope                = azurerm_key_vault.this[0].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value
}

###############################################################
# Disk Encryption Set
###############################################################
resource "azurerm_disk_encryption_set" "this" {
  count = var.enable_disk_encryption ? 1 : 0

  name                      = "des-${local.prefix}-${var.workload}"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.this.name
  key_vault_key_id          = azurerm_key_vault_key.des[0].versionless_id
  auto_key_rotation_enabled = true
  encryption_type           = "EncryptionAtRestWithPlatformAndCustomerKeys"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.des[0].id]
  }

  depends_on = [azurerm_role_assignment.des_crypto]

  tags = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}
