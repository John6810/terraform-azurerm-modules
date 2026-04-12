# ═══════════════════════════════════════════════════════════════════════════════
# VARIABLES — VPN Sites, Connections, P2S & Server Configurations
# ═══════════════════════════════════════════════════════════════════════════════

variable "vpn_shared_key" {
  description = "Pre-shared key (PSK) for S2S VPN connections. Provide via TF_VAR_vpn_shared_key."
  type        = string
  default     = ""
  sensitive   = true
}

variable "vpn_sites" {
  description = "Map of VPN Sites to create"
  type = map(object({
    virtual_hub_key = string
    address_cidrs   = optional(list(string))
    device_vendor   = optional(string)
    device_model    = optional(string)

    links = list(object({
      name          = string
      ip_address    = optional(string)
      fqdn          = optional(string)
      speed_in_mbps = optional(number, 100)
      provider_name = optional(string)

      bgp = optional(object({
        asn             = number
        peering_address = string
      }))
    }))
  }))
  default = {}
}

variable "vpn_connections" {
  description = "Map of VPN Site connections to Virtual Hubs"
  type = map(object({
    vpn_site_key    = string
    virtual_hub_key = string

    internet_security_enabled = optional(bool, true)

    routing = optional(object({
      associated_route_table = optional(string)
      propagated_route_tables = optional(object({
        route_table_ids = optional(list(string), [])
        labels          = optional(list(string), ["default"])
      }))
    }))

    vpn_links = list(object({
      name                                  = string
      bandwidth_mbps                        = optional(number, 100)
      bgp_enabled                           = optional(bool, false)
      connection_mode                       = optional(string, "Default")
      protocol                              = optional(string, "IKEv2")
      ratelimit_enabled                     = optional(bool, false)
      route_weight                          = optional(number, 0)
      shared_key                            = optional(string)
      local_azure_ip_address_enabled        = optional(bool, false)
      policy_based_traffic_selector_enabled = optional(bool, false)

      custom_bgp_address = optional(list(object({
        ip_address          = string
        ip_configuration_id = string
      })))

      ipsec_policy = optional(object({
        dh_group                 = string
        ike_encryption_algorithm = string
        ike_integrity_algorithm  = string
        encryption_algorithm     = string
        integrity_algorithm      = string
        pfs_group                = string
        sa_data_size_kb          = number
        sa_lifetime_sec          = number
      }))
    }))
  }))
  default = {}
}

variable "vpn_server_configurations" {
  description = "Map of VPN Server Configurations (for Point-to-Site)"
  type = map(object({
    vpn_authentication_types = optional(list(string), ["Certificate"])

    client_root_certificates = optional(map(object({
      name             = string
      public_cert_data = string
    })), {})
  }))
  default = {}
}

variable "p2s_gateways" {
  description = "Map of Point-to-Site VPN Gateways"
  type = map(object({
    virtual_hub_key              = string
    vpn_server_configuration_key = string
    scale_unit                   = optional(number, 1)
    dns_servers                  = optional(list(string), [])

    connection_configuration = object({
      name                    = string
      client_address_prefixes = list(string)
    })
  }))
  default = {}
}
