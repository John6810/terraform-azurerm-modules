# ContainerRegistry

Deploys an Azure Container Registry (ACR) with Premium SKU, zone redundancy, geo-replication, network rules, optional management lock, and flexible RBAC role assignments. Names follow the `cr{subscription_acronym}{environment}{region_code}{workload}` convention (no hyphens).

## Usage

### Standalone

```hcl
module "container_registry" {
  source = "github.com/John6810/terraform-azurerm-modules//ContainerRegistry?ref=ContainerRegistry/v1.0.0"

  subscription_acronym = "api"
  environment          = "prod"
  region_code          = "gwc"
  workload             = "001"
  location             = "germanywestcentral"
  resource_group_name  = "rg-api-prod-gwc-acr"

  sku                           = "Premium"
  public_network_access_enabled = false

  role_assignments = {
    aks_kubelet_pull = {
      role_definition_id_or_name = "AcrPull"
      principal_id               = "00000000-0000-0000-0000-000000000000"
      description                = "AKS kubelet identity"
    }
  }

  lock = { kind = "CanNotDelete" }
  tags = { Environment = "Production" }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/ContainerRegistry"
}

inputs = {
  subscription_acronym          = include.sub.locals.subscription_acronym
  environment                   = include.root.inputs.environment
  region_code                   = include.root.inputs.region_code
  workload                      = "001"
  location                      = include.root.inputs.location
  resource_group_name           = dependency.rg.outputs.name
  public_network_access_enabled = false

  role_assignments = {
    aks_kubelet_pull = {
      role_definition_id_or_name = "AcrPull"
      principal_id               = dependency.id_kubelet.outputs.principal_id
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
| name | Explicit registry name (5-50 alphanumeric). If null, computed. | `string` | `null` | No |
| subscription_acronym | Subscription acronym (e.g. api, mgm) | `string` | `null` | No |
| environment | Environment (e.g. prod, nprd) | `string` | `null` | No |
| region_code | Region code (e.g. gwc, weu) | `string` | `null` | No |
| workload | Workload suffix. No hyphens (ACR alphanumeric only). | `string` | `null` | No |
| location | Azure region | `string` | -- | Yes |
| resource_group_name | Resource group name | `string` | -- | Yes |
| sku | Registry SKU: Basic, Standard, Premium | `string` | `"Premium"` | No |
| admin_enabled | Enable admin account (not recommended) | `bool` | `false` | No |
| public_network_access_enabled | Enable public network access | `bool` | `false` | No |
| zone_redundancy_enabled | Enable zone redundancy (Premium only) | `bool` | `true` | No |
| data_endpoint_enabled | Enable data endpoint (Premium only) | `bool` | `true` | No |
| georeplications | Geo-replication configuration | `list(object({...}))` | `[]` | No |
| network_rule_set | Network rule set | `object({...})` | `null` | No |
| role_assignments | Map of role assignments on the ACR. Key is arbitrary. | `map(object({...}))` | `{}` | No |
| lock | Management lock (CanNotDelete or ReadOnly) | `object({ kind = string, name = optional(string) })` | `null` | No |
| tags | Tags | `map(string)` | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| id | Container Registry ID |
| name | Container Registry name |
| login_server | Login server URL (e.g. crapiprodgwc001.azurecr.io) |
| resource | Complete Container Registry resource object |
