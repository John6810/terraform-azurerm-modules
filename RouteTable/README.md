# RouteTable

Creates an Azure Route Table with a configurable set of routes and optional management lock. Supports forced tunneling through a Network Virtual Appliance (NVA) for hub-and-spoke topologies.

## Usage

### Standalone

```hcl
module "route_table" {
  source = "github.com/John6810/terraform-azurerm-modules//RouteTable?ref=RouteTable/v1.0.0"

  subscription_acronym          = "api"
  environment                   = "prod"
  region_code                   = "gwc"
  location                      = "germanywestcentral"
  workload                      = "spoke"
  resource_group_name           = "rg-api-prod-gwc-network"
  bgp_route_propagation_enabled = false

  routes = {
    default_to_nva = {
      name                   = "default-to-nva"
      address_prefix         = "0.0.0.0/0"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = "10.238.200.36"
    }
  }

  tags = { Environment = "Production" }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/RouteTable"
}

inputs = {
  subscription_acronym          = include.sub.locals.subscription_acronym
  environment                   = include.root.inputs.environment
  region_code                   = include.root.inputs.region_code
  location                      = include.root.inputs.location
  workload                      = "spoke"
  resource_group_name           = dependency.rg.outputs.name
  bgp_route_propagation_enabled = false

  routes = {
    default_udr = {
      name                   = "default-udr"
      address_prefix         = "0.0.0.0/0"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = include.sub.locals.networks.connectivity_nva.palo_ilb_frontend_ip
    }
  }

  tags = include.root.inputs.common_tags
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| azurerm | ~> 4.0 |
| time | >= 0.9.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | Explicit Route Table name. If null, computed from naming components. | `string` | `null` | No |
| subscription_acronym | Subscription acronym for naming convention | `string` | `null` | No |
| environment | Environment for naming convention | `string` | `null` | No |
| region_code | Region code for naming convention | `string` | `null` | No |
| workload | Workload name for naming convention | `string` | `null` | No |
| location | Azure region | `string` | -- | Yes |
| resource_group_name | Resource group name | `string` | -- | Yes |
| bgp_route_propagation_enabled | Whether BGP route propagation is enabled | `bool` | `true` | No |
| routes | Map of routes to add. Key is arbitrary. | `map(object({...}))` | `{}` | No |
| lock | Management lock configuration (CanNotDelete or ReadOnly) | `object({ kind = string, name = optional(string) })` | `null` | No |
| tags | Tags to assign | `map(string)` | `{}` | No |

### Route Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | `string` | Yes | Route name |
| address_prefix | `string` | Yes | Destination CIDR or Azure Service Tag |
| next_hop_type | `string` | Yes | `VirtualNetworkGateway`, `VnetLocal`, `Internet`, `VirtualAppliance`, or `None` |
| next_hop_in_ip_address | `string` | No | Next hop IP (required for VirtualAppliance) |

## Outputs

| Name | Description |
|------|-------------|
| id | The route table ID |
| name | The route table name |
| routes | The route definitions applied to the route table |
| resource | Complete route table resource object |
