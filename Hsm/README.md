# Hsm

Deploys an Azure Key Vault Managed Hardware Security Module (HSM) with a user-assigned managed identity, optional inline resource group creation, and an optional Private Endpoint with DNS zone group.

## Usage

### Standalone

```hcl
module "hsm" {
  source = "github.com/John6810/terraform-azurerm-modules//Hsm?ref=Hsm/v1.0.0"

  subscription_acronym = "mgm"
  environment          = "prod"
  region_code          = "gwc"
  workload             = "01"
  location             = "germanywestcentral"

  create_resource_group = true

  sku_name                   = "Standard_B1"
  purge_protection_enabled   = true
  soft_delete_retention_days = 90

  private_endpoint_subnet_id = "/subscriptions/.../subnets/snet-mgm-prod-gwc-pe"
  private_dns_zone_ids       = ["/subscriptions/.../privateDnsZones/privatelink.managedhsm.azure.net"]

  tags = { Environment = "Production" }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/Hsm"
}

inputs = {
  subscription_acronym       = include.sub.locals.subscription_acronym
  environment                = include.root.inputs.environment
  region_code                = include.root.inputs.region_code
  workload                   = "01"
  location                   = include.root.inputs.location
  create_resource_group      = true
  private_endpoint_subnet_id = dependency.subnet.outputs.subnet_ids["snet-mgm-prod-gwc-pe"]
  private_dns_zone_ids       = [dependency.dns_zones.outputs.private_dns_zone_resource_ids["privatelink.managedhsm.azure.net"]]
  tags                       = include.root.inputs.common_tags
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
| name | Optional. Explicit name. If null, computed from naming components. | `string` | `null` | No |
| subscription_acronym | Subscription acronym (e.g. mgm, con) | `string` | `null` | No |
| environment | Environment (e.g. prod, nprd) | `string` | `null` | No |
| region_code | Region code (e.g. gwc, weu) | `string` | `null` | No |
| workload | Workload suffix | `string` | `"01"` | No |
| location | Azure region | `string` | -- | Yes |
| resource_group_name | Resource group name. Required when create_resource_group = false. | `string` | `null` | No |
| create_resource_group | If true, creates the resource group inline. | `bool` | `false` | No |
| resource_group_workload | Workload name for RG naming when create_resource_group = true. | `string` | `"hsm"` | No |
| sku_name | SKU of the Managed HSM | `string` | `"Standard_B1"` | No |
| purge_protection_enabled | Enable purge protection | `bool` | `true` | No |
| soft_delete_retention_days | Soft delete retention in days | `number` | `90` | No |
| admin_object_ids | Admin object IDs. Defaults to current user. | `list(string)` | `[]` | No |
| public_network_access_enabled | Enable public network access | `bool` | `true` | No |
| private_endpoint_subnet_id | Subnet ID for the Private Endpoint. If set, a PE is created. | `string` | `null` | No |
| private_dns_zone_ids | Private DNS Zone IDs for the PE DNS zone group | `list(string)` | `[]` | No |
| tags | Tags to apply | `map(string)` | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| id | The ID of the Managed HSM |
| name | The name of the Managed HSM |
| hsm_uri | The URI of the Managed HSM |
| identity_id | The ID of the HSM User Assigned Identity |
| identity_principal_id | The Principal ID of the HSM User Assigned Identity |
| resource_group_name | The name of the resource group |
| resource_group_id | The ID of the resource group (only when created inline) |
| private_endpoint_id | The ID of the Private Endpoint |
| private_endpoint_ip | The private IP address of the Private Endpoint |
| resource | The complete HSM resource object |
