# ResourceGroup

Creates an Azure Resource Group with automatic name generation following the `rg-{subscription_acronym}-{environment}-{region_code}-{workload}` convention, with optional management lock and RBAC role assignments.

## Usage

### Standalone

```hcl
module "resource_group" {
  source = "github.com/John6810/terraform-azurerm-modules//ResourceGroup?ref=ResourceGroup/v1.0.0"

  subscription_acronym = "api"
  environment          = "prod"
  region_code          = "gwc"
  location             = "germanywestcentral"
  workload             = "aks"

  lock = { kind = "CanNotDelete" }

  role_assignments = {
    aks_contributor = {
      role_definition_id_or_name = "Contributor"
      principal_id               = "00000000-0000-0000-0000-000000000000"
    }
  }

  tags = { Environment = "Production" }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/ResourceGroup"
}

inputs = {
  subscription_acronym = include.sub.locals.subscription_acronym
  environment          = include.root.inputs.environment
  region_code          = include.root.inputs.region_code
  location             = include.root.inputs.location
  workload             = "aks"
  lock                 = { kind = "CanNotDelete" }
  tags                 = include.root.inputs.common_tags
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
| name | Explicit resource group name. If null, computed from naming components. | `string` | `null` | No |
| subscription_acronym | Subscription acronym (e.g. mgm, con, api) | `string` | `null` | No |
| environment | Environment (e.g. prod, nprd) | `string` | `null` | No |
| region_code | Region code (e.g. gwc, weu) | `string` | `null` | No |
| workload | Workload name (e.g. aks, network, identity) | `string` | `null` | No |
| location | Azure region | `string` | -- | Yes |
| tags | Tags to assign to the resource group | `map(string)` | `{}` | No |
| lock | Management lock configuration (CanNotDelete or ReadOnly) | `object({ kind = string, name = optional(string) })` | `null` | No |
| role_assignments | Map of RBAC role assignments at resource group scope. Key is arbitrary. | `map(object({ role_definition_id_or_name = string, principal_id = string, ... }))` | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| id | The resource group ID |
| name | The resource group name |
| location | The Azure region |
| tags | All tags applied, including the auto-generated CreatedOn tag |
| resource | Complete resource group object |
