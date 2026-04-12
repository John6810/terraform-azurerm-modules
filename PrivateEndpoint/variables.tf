###############################################################
# MODULE: PrivateEndpoint - Variables
###############################################################

###############################################################
# REQUIRED VARIABLES
###############################################################
variable "location" {
  type        = string
  description = "Azure region for Private Endpoints"
  nullable    = false
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name"
  nullable    = false
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for deploying Private Endpoints"
  nullable    = false

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.subnet_id))
    error_message = "Subnet ID must be a valid Azure resource ID."
  }
}

###############################################################
# PRIVATE ENDPOINTS
###############################################################
variable "private_endpoints" {
  description = <<-EOT
  A map of Private Endpoint configurations. The map key is deliberately
  arbitrary to avoid issues where map keys may be unknown at plan time.

  - `name`                           - (Required) Private Endpoint name.
  - `resource_id`                    - (Required) Target Azure resource ID.
  - `subresource_names`              - (Required) Subresources to expose (e.g. ["vault"], ["blob"]).
  - `is_manual_connection`           - (Optional) Manual connection requiring approval. Defaults to false.
  - `request_message`                - (Optional) Message for manual connections.
  - `private_ip_address`             - (Optional) Static private IP address.
  - `member_name`                    - (Optional) Member name for IP config. Defaults to "default".
  - `custom_network_interface_name`  - (Optional) Custom NIC name.
  - `private_dns_zone_group`         - (Optional) DNS zone group configuration.
  - `tags`                           - (Optional) Tags specific to this endpoint.
  EOT
  type = map(object({
    name                         = string
    resource_id                  = string
    subresource_names            = list(string)
    is_manual_connection         = optional(bool, false)
    request_message              = optional(string)
    private_ip_address           = optional(string)
    member_name                  = optional(string, "default")
    custom_network_interface_name = optional(string)
    private_dns_zone_group = optional(object({
      name                 = optional(string, "default")
      private_dns_zone_ids = list(string)
    }))
    tags = optional(map(string), {})
  }))
  nullable = false

  validation {
    condition = alltrue([
      for ep in var.private_endpoints :
      length(ep.subresource_names) > 0
    ])
    error_message = "Each Private Endpoint must have at least one subresource in subresource_names."
  }

  validation {
    condition = alltrue([
      for ep in var.private_endpoints :
      can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/", ep.resource_id))
    ])
    error_message = "resource_id must be a valid Azure resource ID."
  }

  validation {
    condition = alltrue([
      for ep in var.private_endpoints :
      ep.private_ip_address == null || can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$", ep.private_ip_address))
    ])
    error_message = "private_ip_address must be a valid IPv4 address."
  }

  validation {
    condition = alltrue([
      for ep in var.private_endpoints :
      !ep.is_manual_connection || (ep.request_message != null && ep.request_message != "")
    ])
    error_message = "request_message is required when is_manual_connection is true."
  }
}

###############################################################
# TAGS
###############################################################
variable "tags" {
  type        = map(string)
  description = "Common tags to apply to all Private Endpoints"
  default     = {}
}
