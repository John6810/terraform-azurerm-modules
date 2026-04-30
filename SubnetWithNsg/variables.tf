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

  - `name`                              - (Required) Subnet name.
  - `address_prefix`                    - (Required) Subnet CIDR block.
  - `nsg_id`                            - (Optional) NSG resource ID to associate.
  - `route_table_id`                    - (Optional) Route Table resource ID to associate.
  - `nat_gateway_id`                    - (Optional) NAT Gateway resource ID. Cannot be set on the AzureFirewallSubnet, GatewaySubnet, AzureBastionSubnet.
  - `service_endpoints`                 - (Optional) List of service endpoints (e.g. ["Microsoft.Storage", "Microsoft.KeyVault"]). Empty = none.
  - `private_endpoint_network_policies` - (Optional) "Enabled", "Disabled", "NetworkSecurityGroupEnabled", "RouteTableEnabled". Default "Disabled" (recommended for PE-hosting subnets; some PEs require this set to Disabled).
  - `default_outbound_access_enabled`   - (Optional) Enable default outbound access. Defaults to false (best practice; outbound through NAT/firewall instead).
  - `delegation`                        - (DEPRECATED, use `delegations`) Single service delegation. Merged with `delegations` if both set.
  - `delegations`                       - (Optional) List of service delegations. Replaces `delegation`. Most subnets need at most one, but the schema allows several.
  EOT
  type = list(object({
    name                              = string
    address_prefix                    = string
    nsg_id                            = optional(string)
    route_table_id                    = optional(string)
    nat_gateway_id                    = optional(string)
    service_endpoints                 = optional(list(string), [])
    private_endpoint_network_policies = optional(string, "Disabled")
    default_outbound_access_enabled   = optional(bool, false)
    delegation = optional(object({
      name         = string
      service_name = string
    }))
    delegations = optional(list(object({
      name         = string
      service_name = string
    })), [])
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

  validation {
    condition = alltrue([
      for s in var.subnets :
      contains(["Enabled", "Disabled", "NetworkSecurityGroupEnabled", "RouteTableEnabled"], s.private_endpoint_network_policies)
    ])
    error_message = "private_endpoint_network_policies must be one of: Enabled, Disabled, NetworkSecurityGroupEnabled, RouteTableEnabled."
  }

  validation {
    condition = alltrue([
      for s in var.subnets :
      s.nat_gateway_id == null || can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/natGateways/[^/]+$", s.nat_gateway_id))
    ])
    error_message = "Each nat_gateway_id, when set, must be a valid Azure NAT Gateway resource ID."
  }
}
