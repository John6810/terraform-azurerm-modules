###############################################################
# MODULE: KeyVault-Key - Main
# Description: Creates Azure Key Vault keys with rotation policies
###############################################################

resource "time_static" "created_at" {}

# Default expiry: 2 years from creation
resource "time_offset" "expiry_plus_2y" {
  base_rfc3339 = time_static.created_at.rfc3339
  offset_years = 2
}

###############################################################
# RESOURCE: Key Vault Keys
###############################################################
resource "azurerm_key_vault_key" "this" {
  for_each = var.keys

  name         = each.value.name
  key_vault_id = each.value.key_vault_id
  key_type     = each.value.key_type
  # RSA keys default to 2048 (Azure minimum, current best-practice for
  # workload secrets — bump to 3072/4096 explicitly when needed). EC
  # keys ignore key_size.
  key_size = each.value.key_size != null ? each.value.key_size : (
    contains(["RSA", "RSA-HSM"], each.value.key_type) ? 2048 : null
  )
  curve    = each.value.curve
  key_opts = each.value.key_opts

  not_before_date = each.value.not_before_date
  expiration_date = coalesce(each.value.expiration_date, time_offset.expiry_plus_2y.rfc3339)

  tags = each.value.tags

  dynamic "rotation_policy" {
    for_each = each.value.rotation_policy != null ? [each.value.rotation_policy] : []
    content {
      expire_after         = rotation_policy.value.expire_after
      notify_before_expiry = rotation_policy.value.notify_before_expiry

      dynamic "automatic" {
        for_each = rotation_policy.value.automatic != null ? [rotation_policy.value.automatic] : []
        content {
          time_after_creation = automatic.value.time_after_creation
          time_before_expiry  = automatic.value.time_before_expiry
        }
      }
    }
  }
}
