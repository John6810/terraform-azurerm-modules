###############################################################
# MODULE: SubnetWithNsg - Variables
###############################################################

variable "virtual_network_id" {
  type        = string
  description = "The full resource ID of the virtual network."
  nullable    = false

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+$", var.virtual_network_id))
    error_message = "virtual_network_id must be a valid Azure Virtual Network resource ID."
  }
}

variable "subnets" {
  description = <<-EOT
  List of subnets to create with NSG attached in a single API call.
  Uses azapi_resource to comply with Azure Policy "Subnets must have a NSG".

  - `name`                            - (Required) Subnet name.
  - `address_prefix`                  - (Required) Subnet CIDR block.
  - `nsg_id`                          - (Optional) NSG resource ID to associate.
  - `route_table_id`                  - (Optional) Route Table resource ID to associate.
  - `default_outbound_access_enabled` - (Optional) Enable default outbound access. Defaults to false.
  - `delegation`                      - (Optional) Service delegation configuration.
  EOT
  type = list(object({
    name                            = string
    address_prefix                  = string
    nsg_id                          = optional(string)
    route_table_id                  = optional(string)
    default_outbound_access_enabled = optional(bool, false)
    delegation = optional(object({
      name         = string
      service_name = string
    }))
  }))
  nullable = false

  validation {
    condition = alltrue([
      for s in var.subnets :
      can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}/\\d{1,2}$", s.address_prefix))
    ])
    error_message = "Each subnet address_prefix must be a valid CIDR block (e.g. 10.0.1.0/24)."
  }

  validation {
    condition     = length(var.subnets) == length(distinct([for s in var.subnets : s.name]))
    error_message = "Each subnet name must be unique."
  }
}
