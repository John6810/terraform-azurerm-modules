# ═══════════════════════════════════════════════════════════════════════════════
# VARIABLES — Virtual Hubs, VNet Connections & BGP
# ═══════════════════════════════════════════════════════════════════════════════

variable "virtual_hubs" {
  description = "Map of Virtual Hubs to create"
  type = map(object({
    address_prefix = string
    location       = optional(string)
    sku            = optional(string, "Standard")
    routes = optional(list(object({
      address_prefixes    = list(string)
      next_hop_ip_address = string
    })), [])

    # VPN Gateway configuration
    vpn_gateway = optional(object({
      scale_unit                            = optional(number, 1)
      bgp_route_translation_for_nat_enabled = optional(bool, false)
      routing_preference                    = optional(string, "Microsoft Network")
    }))

    # ExpressRoute Gateway configuration
    express_route_gateway = optional(object({
      scale_units                   = optional(number, 1)
      allow_non_virtual_wan_traffic = optional(bool, false)
    }))

    # Azure Firewall configuration
    firewall = optional(object({
      sku_name           = optional(string, "AZFW_Hub")
      sku_tier           = optional(string, "Standard")
      firewall_policy_id = optional(string)
      dns_servers        = optional(list(string))
      private_ip_ranges  = optional(list(string))
      threat_intel_mode  = optional(string, "Alert")
      zones              = optional(list(string))
    }))
  }))
  default = {}
}

variable "virtual_hub_connections" {
  description = "Map of Virtual Hub VNet connections"
  type = map(object({
    virtual_hub_key           = string
    remote_virtual_network_id = string
    internet_security_enabled = optional(bool, false)
  }))
  default = {}
}

variable "bgp_connections" {
  description = "Map of Virtual Hub BGP connections (NVA peering)"
  type = map(object({
    virtual_hub_key            = string
    virtual_hub_connection_key = string
    peer_asn                   = number
    peer_ip                    = string
  }))
  default = {}
}

variable "express_route_connections" {
  description = "Map of ExpressRoute Connections binding an ExpressRoute circuit AzurePrivatePeering to a hub ER Gateway"
  type = map(object({
    virtual_hub_key                  = string
    express_route_circuit_peering_id = string
    authorization_key                = optional(string)
    routing_weight                   = optional(number, 0)
  }))
  default = {}
}
