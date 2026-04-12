# StorageAccount

Creates an Azure Storage Account with configurable replication, network access, identity, blob/container retention, optional containers, management lock, and RBAC role assignments. Names follow `st{subscription_acronym}{environment}{region_code}{workload}` (lowercase alphanumeric only).

## Usage

### Standalone

```hcl
module "storage_account" {
  source = "github.com/John6810/terraform-azurerm-modules//StorageAccount?ref=StorageAccount/v1.0.0"

  subscription_acronym = "mgm"
  environment          = "prod"
  region_code          = "gwc"
  workload             = "diag"
  location             = "germanywestcentral"
  resource_group_name  = "rg-mgm-prod-gwc-storage"

  account_replication_type      = "ZRS"
  public_network_access_enabled = false

  role_assignments = {
    blob_contributor = {
      role_definition_id_or_name = "Storage Blob Data Contributor"
      principal_id               = "00000000-0000-0000-0000-000000000000"
    }
  }

  lock = { kind = "CanNotDelete" }
  tags = { Environment = "Production" }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/StorageAccount"
}

inputs = {
  subscription_acronym          = include.sub.locals.subscription_acronym
  environment                   = include.root.inputs.environment
  region_code                   = include.root.inputs.region_code
  workload                      = "diag"
  location                      = include.root.inputs.location
  resource_group_name           = dependency.rg.outputs.name
  public_network_access_enabled = false
  tags                          = include.root.inputs.common_tags
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
| name | Explicit name (3-24 lowercase alphanumeric). If null, computed. | `string` | `null` | No |
| subscription_acronym | Subscription acronym (e.g. mgm, api) | `string` | `null` | No |
| environment | Environment (e.g. prod, nprd) | `string` | `null` | No |
| region_code | Region code (e.g. gwc, weu) | `string` | `null` | No |
| workload | Workload suffix. Lowercase alphanumeric only. | `string` | `null` | No |
| location | Azure region | `string` | -- | Yes |
| resource_group_name | Resource group name | `string` | -- | Yes |
| account_tier | Standard or Premium | `string` | `"Standard"` | No |
| account_replication_type | LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS | `string` | `"ZRS"` | No |
| account_kind | StorageV2, BlobStorage, BlockBlobStorage, FileStorage | `string` | `"StorageV2"` | No |
| public_network_access_enabled | Enable public network access | `bool` | `false` | No |
| shared_access_key_enabled | Enable shared access keys | `bool` | `false` | No |
| identity_type | SystemAssigned, UserAssigned, or both | `string` | `null` | No |
| blob_delete_retention_days | Retention days for deleted blobs (1-365) | `number` | `30` | No |
| container_delete_retention_days | Retention days for deleted containers (1-365) | `number` | `30` | No |
| containers | Map of containers to create. Key is arbitrary. | `map(object({...}))` | `{}` | No |
| role_assignments | Map of role assignments on the Storage Account. Key is arbitrary. | `map(object({...}))` | `{}` | No |
| lock | Management lock (CanNotDelete or ReadOnly) | `object({ kind = string, name = optional(string) })` | `null` | No |
| tags | Tags | `map(string)` | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| id | Storage Account ID |
| name | Storage Account name |
| primary_blob_endpoint | Primary blob endpoint URL |
| primary_access_key | Primary access key (sensitive) |
| resource | Complete Storage Account resource object |
