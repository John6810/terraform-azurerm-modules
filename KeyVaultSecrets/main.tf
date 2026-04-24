###############################################################
# MODULE: KeyVaultSecrets - Main
# Description: Push secrets to a Key Vault. Supports random generation.
###############################################################

locals {
  generated_secrets = { for k, v in var.secrets : k => v if v.generate != null }
}

###############################################################
# RESOURCE: Random Passwords
###############################################################
resource "random_password" "this" {
  for_each = local.generated_secrets

  length           = each.value.generate.length
  special          = each.value.generate.special
  override_special = each.value.generate.override_special
}

###############################################################
# RESOURCE: Key Vault Secrets
###############################################################
resource "azurerm_key_vault_secret" "this" {
  for_each = var.secrets

  name  = each.value.name
  value = coalesce(each.value.value, try(random_password.this[each.key].result, null))

  key_vault_id    = var.key_vault_id
  content_type    = each.value.content_type
  expiration_date = each.value.expiration_date
  tags            = each.value.tags

  # Ignore value drift so we can rotate out-of-band without Terraform reverting.
  lifecycle {
    ignore_changes = [value]
  }
}
