# Vnet

Creates an Azure Virtual Network with configurable address spaces, DNS servers, optional DDoS protection, management lock, and optional inline subnets with NSG/RT/NAT associations.

## Usage

### Standalone

```hcl
module "vnet" {
  source = "github.com/John6810/terraform-azurerm-modules//Vnet?ref=Vnet/v1.0.0"

  subscription_acronym = "api"
  environment          = "prod"
  region_code          = "gwc"
  workload             = "spoke"
  location             = "germanywestcentral"
  resource_group_name  = "rg-api-prod-gwc-network"

  address_space = ["10.238.0.0/21"]
  dns_servers   = ["10.238.200.68"]

  lock = { kind = "CanNotDelete" }
  tags = { Environment = "Production" }
}
```

### Terragrunt (with inline subnets)

```hcl
terraform {
  source = "${get_repo_root()}/modules/Vnet"
}

inputs = {
  subscription_acronym = include.sub.locals.subscription_acronym
  environment          = include.root.inputs.environment
  region_code          = include.root.inputs.region_code
  workload             = "spoke"
  location             = include.root.inputs.location
  resource_group_name  = dependency.rg.outputs.name
  address_space        = include.sub.locals.networks.corp_apimanager.address_space
  dns_servers          = [dependency.dns_resolver.outputs.inbound_endpoint_ip]

  subnets = [
    {
      name             = "snet-api-prod-gwc-nodes"
      address_prefixes = ["10.238.1.0/24"]
      nsg_id           = dependency.nsg.outputs.ids["nodes"]
      route_table_id   = dependency.rt.outputs.id
    }
  ]

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
| name | Explicit VNet name. If null, computed. | `string` | `null` | No |
| subscription_acronym | Subscription acronym (e.g. mgm, con, api) | `string` | `null` | No |
| environment | Environment (e.g. prod, nprd) | `string` | `null` | No |
| region_code | Region code (e.g. gwc, weu) | `string` | `null` | No |
| workload | Workload name (e.g. hub, spoke) | `string` | `null` | No |
| location | Azure region | `string` | -- | Yes |
| resource_group_name | Resource group name | `string` | -- | Yes |
| address_space | VNet CIDR address space | `list(string)` | `null` | No |
| dns_servers | Custom DNS server IPs | `list(string)` | `null` | No |
| enable_ddos_protection | Enable DDoS Standard protection | `bool` | `false` | No |
| ddos_protection_plan_id | DDoS Protection Plan ID | `string` | `null` | No |
| ip_address_pool | Azure IPAM pool configuration | `object({...})` | `null` | No |
| subnets | Inline subnets with NSG/RT/NAT associations | `list(object({...}))` | `[]` | No |
| lock | Management lock (CanNotDelete or ReadOnly) | `object({ kind = string, name = optional(string) })` | `null` | No |
| tags | Tags to assign | `map(string)` | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| id | VNet resource ID |
| name | VNet name |
| resource_group_name | Resource group name |
| location | Azure region |
| tags | Tags applied |
| resource | Complete VNet resource object |
| subnet_ids | Map of subnet name => subnet ID |
| subnet_names | Map of subnet name => subnet name |
