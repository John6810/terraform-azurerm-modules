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
| georeplications | Geo-replication configuration (Premium only) | `list(object({...}))` | `[]` | No |
| network_rule_set | Network rule set | `object({...})` | `null` | No |
| anonymous_pull_enabled | Allow unauthenticated repository read | `bool` | `false` | No |
| export_policy_enabled | Allow exporting repository metadata (Premium only) | `bool` | `true` | No |
| retention_policy_in_days | Auto-purge untagged manifests after N days (1-365, Premium only). null = never. | `number` | `null` | No |
| trust_policy_enabled | Enable content trust / image signing (Premium only) | `bool` | `false` | No |
| identity_ids | UAMI IDs to attach to the registry. Required if customer_managed_key is set. | `list(string)` | `[]` | No |
| customer_managed_key | CMK encryption (Premium only). Object: `{ key_vault_key_id, identity_client_id }` | `object({...})` | `null` | No |
| diagnostic_setting | Optional diag setting → LAW. Object: `{ name?, log_analytics_workspace_id, categories?, metrics_enabled? }` | `object({...})` | `null` | No |
| role_assignments | Map of role assignments on the ACR. Key is arbitrary. | `map(object({...}))` | `{}` | No |
| lock | Management lock (CanNotDelete or ReadOnly) | `object({ kind = string, name = optional(string) })` | `null` | No |
| tags | Tags | `map(string)` | `{}` | No |

## Premium-only features

`customer_managed_key`, `retention_policy_in_days`, `trust_policy_enabled`, `export_policy_enabled` (effective enforcement), `georeplications`, `zone_redundancy_enabled`, `data_endpoint_enabled` all require `sku = "Premium"`. A precondition catches misconfigurations at plan time.

### CMK example

```hcl
identity_ids = [azurerm_user_assigned_identity.acr.id]

customer_managed_key = {
  key_vault_key_id   = azurerm_key_vault_key.acr_cmk.versionless_id
  identity_client_id = azurerm_user_assigned_identity.acr.client_id
}
```

The UAMI must hold `Key Vault Crypto User` on the Key Vault hosting the key. Use the **versionless** key URI to enable rotation without recreating the registry.

### Diagnostic settings

```hcl
diagnostic_setting = {
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.platform.id
  # default categories: ContainerRegistryRepositoryEvents + ContainerRegistryLoginEvents
  # default metrics_enabled: true
}
```

## Outputs

| Name | Description |
|------|-------------|
| id | Container Registry ID |
| name | Container Registry name |
| login_server | Login server URL (e.g. crapiprodgwc001.azurecr.io) |
| resource | Complete Container Registry resource object |
