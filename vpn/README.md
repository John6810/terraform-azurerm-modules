# vpn

Creates an Azure VPN Gateway (VpnGw1AZ) with site-to-site connections, local network gateways, and BGP configuration for hybrid connectivity in a hub VNet.

## Usage

### Standalone

```hcl
module "vpn" {
  source = "github.com/John6810/terraform-azurerm-modules//vpn?ref=vpn/v1.0.0"

  subscription_acronym = "con"
  environment          = "prod"
  region_code          = "gwc"
  workload             = "001"
  location             = "germanywestcentral"
  resource_group_name  = "rg-con-prod-gwc-connectivity"
  subnet_id            = "/subscriptions/.../subnets/GatewaySubnet"

  sku           = "VpnGw1AZ"
  active_active = false
  enable_bgp    = false

  local_network_gateways = {
    onprem = {
      gateway_address = "203.0.113.1"
      address_space   = ["10.0.0.0/16"]
      shared_key      = "SuperSecretKey"
    }
  }

  tags = { Environment = "Production" }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/vpn"
}

inputs = {
  subscription_acronym = include.sub.locals.subscription_acronym
  environment          = include.root.inputs.environment
  region_code          = include.root.inputs.region_code
  location             = include.root.inputs.location
  resource_group_name  = dependency.rg.outputs.name
  subnet_id            = dependency.subnet.outputs.subnet_ids["GatewaySubnet"]
  tags                 = include.root.inputs.common_tags
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| azurerm | ~> 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | Explicit VPN Gateway name. If null, computed. | `string` | `null` | No |
| subscription_acronym | Subscription acronym (e.g. mgm, con, api) | `string` | `null` | No |
| environment | Environment (e.g. prod, nprd) | `string` | `null` | No |
| region_code | Region code (e.g. gwc, weu) | `string` | `null` | No |
| workload | Workload name (e.g. hub, 001) | `string` | `null` | No |
| location | Azure region | `string` | -- | Yes |
| resource_group_name | Resource group name | `string` | -- | Yes |
| subnet_id | ID of the GatewaySubnet | `string` | -- | Yes |
| sku | VPN Gateway SKU | `string` | `"VpnGw1"` | No |
| type | Gateway type (Vpn or ExpressRoute) | `string` | `"Vpn"` | No |
| vpn_type | VPN type (RouteBased or PolicyBased) | `string` | `"RouteBased"` | No |
| generation | VPN Gateway generation | `string` | `"Generation1"` | No |
| enable_bgp | Enable BGP | `bool` | `false` | No |
| active_active | Enable active-active mode | `bool` | `false` | No |
| private_ip_address_allocation | Private IP allocation (Dynamic or Static) | `string` | `"Dynamic"` | No |
| bgp_settings | BGP settings (asn, peer_weight) | `object({...})` | `null` | No |
| vpn_client_configuration | Point-to-Site VPN client configuration | `object({...})` | `null` | No |
| local_network_gateways | Map of local network gateways and S2S connections | `map(object({...}))` | `{}` | No |
| tags | Tags to assign | `map(string)` | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| resource | Complete Virtual Network Gateway resource object |
| vpn_gateway_id | VPN Gateway ID |
| vpn_gateway_name | VPN Gateway name |
| vpn_gateway_public_ip | Primary public IP address |
| vpn_gateway_public_ip_id | Primary public IP ID |
| vpn_gateway_public_ip_secondary | Secondary public IP (if active-active) |
| vpn_gateway_public_ip_secondary_id | Secondary public IP ID (if active-active) |
| vpn_gateway_bgp_settings | BGP settings (if enabled) |
| local_network_gateway_ids | Map of local network gateway IDs |
| connection_ids | Map of VPN connection IDs |
