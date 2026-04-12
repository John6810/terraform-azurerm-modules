###############################################################
# MODULE: VNetPeering - Variables
###############################################################

variable "peerings" {
  description = <<-EOT
  Map of VNet peerings to create. The map key is the peering name.

  - `virtual_network_name`         - (Required) Local VNet name.
  - `resource_group_name`          - (Required) Local VNet resource group name.
  - `remote_virtual_network_id`    - (Required) Remote VNet resource ID.
  - `allow_forwarded_traffic`      - (Optional) Allow forwarded traffic. Defaults to true.
  - `allow_gateway_transit`        - (Optional) Allow gateway transit. Defaults to false.
  - `allow_virtual_network_access` - (Optional) Allow VNet access. Defaults to true.
  - `use_remote_gateways`          - (Optional) Use remote gateways. Defaults to false.
  EOT
  type = map(object({
    virtual_network_name         = string
    resource_group_name          = string
    remote_virtual_network_id    = string
    allow_forwarded_traffic      = optional(bool, true)
    allow_gateway_transit        = optional(bool, false)
    allow_virtual_network_access = optional(bool, true)
    use_remote_gateways          = optional(bool, false)
  }))
  nullable = false

  validation {
    condition = alltrue([
      for k, v in var.peerings :
      can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+$", v.remote_virtual_network_id))
    ])
    error_message = "remote_virtual_network_id must be a valid Azure Virtual Network resource ID."
  }
}
