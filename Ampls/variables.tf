###############################################################
# MODULE: Ampls - Variables
###############################################################

variable "ampls_name" {
  type        = string
  description = "Name of the Azure Monitor Private Link Scope"
  nullable    = false
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group"
  nullable    = false
}

variable "location" {
  type        = string
  description = "Azure region"
  nullable    = false
}

variable "ingestion_access_mode" {
  type        = string
  description = "AMPLS ingestion access mode: Open or PrivateOnly"
  default     = "PrivateOnly"

  validation {
    condition     = contains(["Open", "PrivateOnly"], var.ingestion_access_mode)
    error_message = "ingestion_access_mode must be Open or PrivateOnly."
  }
}

variable "query_access_mode" {
  type        = string
  description = "AMPLS query access mode: Open or PrivateOnly"
  default     = "PrivateOnly"

  validation {
    condition     = contains(["Open", "PrivateOnly"], var.query_access_mode)
    error_message = "query_access_mode must be Open or PrivateOnly."
  }
}

variable "scoped_services" {
  description = "Map of services to link to the AMPLS (e.g. law, dce). Key = logical name."
  type = map(object({
    resource_id = string
  }))
  nullable = false

  validation {
    condition = alltrue([
      for k, v in var.scoped_services :
      can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/", v.resource_id))
    ])
    error_message = "Each scoped_service resource_id must be a valid Azure resource ID."
  }
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for the private endpoint"
  nullable    = false

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.subnet_id))
    error_message = "subnet_id must be a valid Azure Subnet resource ID."
  }
}

variable "private_dns_zone_ids" {
  type        = list(string)
  description = "List of private DNS zone IDs for the PE DNS zone group"
  nullable    = false
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}
