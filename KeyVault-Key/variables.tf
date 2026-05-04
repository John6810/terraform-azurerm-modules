###############################################################
# MODULE: KeyVault-Key - Variables
###############################################################

variable "keys" {
  description = <<-EOT
  Map of Key Vault keys to create. The map key is used as the resource identifier.

  - `name`            - (Required) Key name.
  - `key_vault_id`    - (Required) Full Key Vault resource ID.
  - `key_type`        - (Required) RSA, EC, RSA-HSM, or EC-HSM.
  - `key_size`        - (Optional) 2048, 3072, or 4096 (required for RSA).
  - `curve`           - (Optional) P-256, P-384, P-521, or P-256K (required for EC).
  - `key_opts`        - (Optional) Key operations. Defaults to all operations.
  - `not_before_date` - (Optional) Key not usable before this UTC datetime (Y-m-d'T'H:M:S'Z').
  - `expiration_date` - (Optional) Key expiration UTC datetime. Defaults to +2 years.
  - `tags`            - (Optional) Key-specific tags.
  - `rotation_policy` - (Optional) Automatic rotation configuration (ISO 8601 durations).
  EOT
  type = map(object({
    name            = string
    key_vault_id    = string
    key_type        = string
    key_size        = optional(number)
    curve           = optional(string)
    key_opts        = optional(list(string), ["encrypt", "decrypt", "wrapKey", "unwrapKey", "sign", "verify"])
    not_before_date = optional(string)
    expiration_date = optional(string)
    tags            = optional(map(string), {})
    rotation_policy = optional(object({
      expire_after         = optional(string)
      notify_before_expiry = optional(string)
      automatic = optional(object({
        time_after_creation = optional(string)
        time_before_expiry  = optional(string)
      }))
    }))
  }))
  nullable = false

  validation {
    condition = alltrue([
      for k, v in var.keys :
      contains(["RSA", "EC", "RSA-HSM", "EC-HSM"], v.key_type)
    ])
    error_message = "key_type must be one of: RSA, EC, RSA-HSM, EC-HSM."
  }

  validation {
    condition = alltrue([
      for k, v in var.keys :
      !contains(["RSA", "RSA-HSM"], v.key_type) || (
        v.key_size == null || contains([2048, 3072, 4096], v.key_size)
      )
    ])
    error_message = "For RSA keys, key_size must be 2048, 3072, or 4096 (or null to default to 2048)."
  }

  validation {
    condition = alltrue([
      for k, v in var.keys :
      v.rotation_policy == null || v.rotation_policy.automatic == null ||
      v.rotation_policy.automatic.time_after_creation != null ||
      v.rotation_policy.automatic.time_before_expiry != null
    ])
    error_message = "rotation_policy.automatic requires at least one of time_after_creation or time_before_expiry to be set (Azure rejects an empty automatic block)."
  }

  validation {
    condition = alltrue([
      for k, v in var.keys :
      !contains(["EC", "EC-HSM"], v.key_type) || (
        v.curve != null && contains(["P-256", "P-384", "P-521", "P-256K"], v.curve)
      )
    ])
    error_message = "For EC keys, curve must be one of: P-256, P-384, P-521, P-256K."
  }

  validation {
    condition = alltrue([
      for k, v in var.keys :
      can(regex("/subscriptions/[a-f0-9-]+/resourceGroups/[^/]+/providers/Microsoft\\.KeyVault/vaults/[^/]+$", v.key_vault_id))
    ])
    error_message = "key_vault_id must be a valid Azure Key Vault resource ID."
  }

  validation {
    condition = alltrue([
      for k, v in var.keys :
      v.expiration_date == null || can(regex("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$", v.expiration_date))
    ])
    error_message = "expiration_date must be in UTC datetime format: Y-m-dTH:M:SZ."
  }

  validation {
    condition = alltrue([
      for k, v in var.keys :
      v.not_before_date == null || can(regex("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$", v.not_before_date))
    ])
    error_message = "not_before_date must be in UTC datetime format: Y-m-dTH:M:SZ."
  }
}
