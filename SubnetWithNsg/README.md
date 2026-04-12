# SubnetWithNsg

Creates one or more Azure subnets with NSG attached in a single API call using `azapi_resource`. This is required when Azure Policy "Subnets must have a Network Security Group" is set to Deny, as the standard `azurerm_subnet` + `azurerm_subnet_network_security_group_association` two-step approach is blocked.

**Important:** Output keys in `subnet_ids` use the **full subnet name** (e.g. `snet-api-prod-gwc-nodes`), not short names.

## Usage

### Standalone

```hcl
module "subnet" {
  source = "github.com/John6810/terraform-azurerm-modules//SubnetWithNsg?ref=SubnetWithNsg/v1.0.0"

  virtual_network_id = "/subscriptions/.../virtualNetworks/vnet-api-prod-gwc-spoke"

  subnets = [
    {
      name           = "snet-api-prod-gwc-nodes"
      address_prefix = "10.238.1.0/24"
      nsg_id         = "/subscriptions/.../networkSecurityGroups/nsg-api-prod-gwc-nodes"
      route_table_id = "/subscriptions/.../routeTables/rt-api-prod-gwc-spoke"
    },
    {
      name           = "snet-api-prod-gwc-pe"
      address_prefix = "10.238.2.0/24"
      nsg_id         = "/subscriptions/.../networkSecurityGroups/nsg-api-prod-gwc-pe"
      route_table_id = "/subscriptions/.../routeTables/rt-api-prod-gwc-spoke"
    }
  ]
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/SubnetWithNsg"
}

inputs = {
  virtual_network_id = dependency.network.outputs.id

  subnets = [
    {
      name           = include.sub.locals.networks.corp_apimanager.subnets.nodes.name
      address_prefix = include.sub.locals.networks.corp_apimanager.subnets.nodes.cidr
      nsg_id         = dependency.nsg.outputs.ids["nodes"]
      route_table_id = dependency.rt.outputs.id
    },
    {
      name           = include.sub.locals.networks.corp_apimanager.subnets.apiserver.name
      address_prefix = include.sub.locals.networks.corp_apimanager.subnets.apiserver.cidr
      nsg_id         = dependency.nsg.outputs.ids["apiserver"]
      route_table_id = dependency.rt.outputs.id
      delegation = {
        name         = "aks-apiserver"
        service_name = "Microsoft.ContainerService/managedClusters"
      }
    }
  ]
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| azapi | ~> 2.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| virtual_network_id | Full resource ID of the virtual network | `string` | -- | Yes |
| subnets | List of subnets to create with NSG in a single API call | `list(object({...}))` | -- | Yes |

### Subnet Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| name | `string` | Yes | Subnet name (full name, e.g. snet-api-prod-gwc-nodes) |
| address_prefix | `string` | Yes | CIDR block (e.g. 10.238.1.0/24) |
| nsg_id | `string` | No | NSG resource ID to associate |
| route_table_id | `string` | No | Route Table resource ID to associate |
| default_outbound_access_enabled | `bool` | No | Enable default outbound access (default: false) |
| delegation | `object` | No | Service delegation (name + service_name) |

## Outputs

| Name | Description |
|------|-------------|
| subnet_ids | Map of full subnet name => subnet ID |
| resources | Map of full subnet name => complete azapi_resource object |
