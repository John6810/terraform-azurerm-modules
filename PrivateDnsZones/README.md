# PrivateDnsZones

Creates a dedicated resource group and deploys the full set of Azure Private Link Private DNS Zones using the official AVM pattern module (`Azure/avm-ptn-network-private-link-private-dns-zones/azurerm`). Optionally links all zones to one or more virtual networks.

## Usage

### Standalone

```hcl
module "private_dns_zones" {
  source = "github.com/John6810/terraform-azurerm-modules//PrivateDnsZones?ref=PrivateDnsZones/v1.0.0"

  subscription_acronym = "con"
  environment          = "prod"
  region_code          = "gwc"
  location             = "germanywestcentral"

  virtual_network_links = {
    hub = {
      virtual_network_resource_id = "/subscriptions/.../virtualNetworks/vnet-con-prod-gwc-hub"
    }
    spoke-api = {
      virtual_network_resource_id = "/subscriptions/.../virtualNetworks/vnet-api-prod-gwc-spoke"
    }
  }

  tags = { Environment = "Production" }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/PrivateDnsZones"
}

inputs = {
  subscription_acronym = include.sub.locals.subscription_acronym
  environment          = include.root.inputs.environment
  region_code          = include.root.inputs.region_code
  location             = include.root.inputs.location

  virtual_network_links = {
    hub = {
      virtual_network_resource_id = dependency.hub_vnet.outputs.id
    }
  }

  tags = include.root.inputs.common_tags
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| azurerm | ~> 4.0 |
| time | >= 0.9 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| subscription_acronym | Subscription acronym (e.g. con) | `string` | -- | Yes |
| environment | Environment (e.g. prod, nprd) | `string` | -- | Yes |
| region_code | Region code (e.g. gwc) | `string` | -- | Yes |
| location | Azure region | `string` | -- | Yes |
| tags | Tags | `map(string)` | `{}` | No |
| virtual_network_links | VNets to link to all DNS zones. Key = logical name. | `map(object({ virtual_network_resource_id = string }))` | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| resource_group_name | The DNS resource group name |
| resource_group_id | The DNS resource group ID |
| private_dns_zone_resource_ids | Map of private DNS zone names to their resource IDs |
