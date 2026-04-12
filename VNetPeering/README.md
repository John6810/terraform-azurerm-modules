# VNetPeering

Creates Azure VNet peerings. Each entry in the map creates one peering direction. For bidirectional peering, create two entries (A→B and B→A).

## Usage

### Standalone

```hcl
module "vnet_peering" {
  source = "github.com/John6810/terraform-azurerm-modules//VNetPeering?ref=VNetPeering/v1.0.0"

  peerings = {
    "hub-to-spoke" = {
      virtual_network_name      = "vnet-con-prod-gwc-hub"
      resource_group_name       = "rg-con-prod-gwc-network"
      remote_virtual_network_id = "/subscriptions/.../virtualNetworks/vnet-api-prod-gwc-spoke"
      allow_forwarded_traffic   = true
      allow_gateway_transit     = true
    }
    "spoke-to-hub" = {
      virtual_network_name      = "vnet-api-prod-gwc-spoke"
      resource_group_name       = "rg-api-prod-gwc-network"
      remote_virtual_network_id = "/subscriptions/.../virtualNetworks/vnet-con-prod-gwc-hub"
      allow_forwarded_traffic   = true
      use_remote_gateways       = true
    }
  }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/VNetPeering"
}

inputs = {
  peerings = {
    "mgmt-to-nva" = {
      virtual_network_name      = dependency.network_mgmt.outputs.name
      resource_group_name       = dependency.network_mgmt.outputs.resource_group_name
      remote_virtual_network_id = dependency.network_nva.outputs.id
      allow_forwarded_traffic   = true
    }
    "nva-to-mgmt" = {
      virtual_network_name      = dependency.network_nva.outputs.name
      resource_group_name       = dependency.network_nva.outputs.resource_group_name
      remote_virtual_network_id = dependency.network_mgmt.outputs.id
      allow_forwarded_traffic   = true
    }
  }
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
| peerings | Map of VNet peerings. Key = peering name. | `map(object({...}))` | -- | Yes |

### Peering Object

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| virtual_network_name | `string` | Yes | -- | Local VNet name |
| resource_group_name | `string` | Yes | -- | Local VNet resource group |
| remote_virtual_network_id | `string` | Yes | -- | Remote VNet resource ID |
| allow_forwarded_traffic | `bool` | No | `true` | Allow forwarded traffic |
| allow_gateway_transit | `bool` | No | `false` | Allow gateway transit |
| allow_virtual_network_access | `bool` | No | `true` | Allow VNet access |
| use_remote_gateways | `bool` | No | `false` | Use remote gateways |

## Outputs

| Name | Description |
|------|-------------|
| ids | Map of peering key => peering ID |
| resources | Map of peering key => complete peering resource object |
