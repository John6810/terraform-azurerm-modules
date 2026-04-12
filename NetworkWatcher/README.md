# NetworkWatcher

Creates an Azure Network Watcher resource with optional management lock. Optionally creates its own resource group inline when no existing resource group is provided.

## Usage

### Standalone

```hcl
module "network_watcher" {
  source = "github.com/John6810/terraform-azurerm-modules//NetworkWatcher?ref=NetworkWatcher/v1.0.0"

  subscription_acronym    = "con"
  environment             = "prod"
  region_code             = "gwc"
  location                = "germanywestcentral"
  create_resource_group   = true
  resource_group_workload = "network"

  lock = { kind = "CanNotDelete" }
  tags = { Environment = "Production" }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/NetworkWatcher"
}

inputs = {
  subscription_acronym    = include.sub.locals.subscription_acronym
  environment             = include.root.inputs.environment
  region_code             = include.root.inputs.region_code
  location                = include.root.inputs.location
  create_resource_group   = true
  resource_group_workload = "network"
  tags                    = include.root.inputs.common_tags
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
| name | Explicit name. If null, computed from naming components. | `string` | `null` | No |
| subscription_acronym | Subscription acronym (e.g. mgm, con) | `string` | `null` | No |
| environment | Environment (e.g. prod, nprd) | `string` | `null` | No |
| region_code | Region code (e.g. gwc, weu) | `string` | `null` | No |
| workload | Optional workload suffix. If null, name will be nw-{sub}-{env}-{region}. | `string` | `null` | No |
| location | Azure region | `string` | -- | Yes |
| resource_group_name | Resource group name. Required when create_resource_group = false. | `string` | `null` | No |
| create_resource_group | If true, creates the resource group inline. | `bool` | `false` | No |
| resource_group_workload | Workload name for RG naming when create_resource_group = true. | `string` | `"network"` | No |
| lock | Management lock configuration (CanNotDelete or ReadOnly) | `object({ kind = string, name = optional(string) })` | `null` | No |
| tags | Tags to apply | `map(string)` | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| id | The ID of the Network Watcher |
| name | The name of the Network Watcher |
| resource | Complete Network Watcher resource object |
| resource_group_name | The name of the resource group |
| resource_group_id | The ID of the resource group (only when created inline) |
