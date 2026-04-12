# KeyVault

Deploys an Azure Key Vault with RBAC authorization, network ACLs, soft delete, purge protection, optional management lock, and role assignments. Does not include a Private Endpoint -- use the separate `PrivateEndpoint` module for that.

## Usage

### Standalone

```hcl
module "key_vault" {
  source = "github.com/John6810/terraform-azurerm-modules//KeyVault?ref=KeyVault/v1.0.0"

  subscription_acronym = "api"
  environment          = "prod"
  region_code          = "gwc"
  workload             = "apim"
  location             = "germanywestcentral"
  resource_group_name  = "rg-api-prod-gwc-kv"

  sku_name                      = "premium"
  enable_rbac                   = true
  public_network_access_enabled = false
  purge_protection_enabled      = true

  network_acls = {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  role_assignments = {
    aks_secrets_user = {
      role_definition_id_or_name = "Key Vault Secrets User"
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
  source = "${get_repo_root()}/modules/KeyVault"
}

inputs = {
  subscription_acronym          = include.sub.locals.subscription_acronym
  environment                   = include.root.inputs.environment
  region_code                   = include.root.inputs.region_code
  workload                      = "apim"
  location                      = include.root.inputs.location
  resource_group_name           = dependency.rg.outputs.name
  public_network_access_enabled = false

  role_assignments = {
    kubelet_secrets_user = {
      role_definition_id_or_name = "Key Vault Secrets User"
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
| name | Explicit Key Vault name (3-24 chars). If null, computed. | `string` | `null` | No |
| subscription_acronym | Subscription acronym (e.g. mgm, api) | `string` | `null` | No |
| environment | Environment (e.g. prod, nprd) | `string` | `null` | No |
| region_code | Region code (e.g. gwc, weu) | `string` | `null` | No |
| workload | Workload name. Keep short (max 24 chars total name). | `string` | `null` | No |
| location | Azure region | `string` | -- | Yes |
| resource_group_name | Resource group name | `string` | -- | Yes |
| tenant_id | Azure AD tenant ID (auto-detected if null) | `string` | `null` | No |
| sku_name | SKU: standard or premium (HSM-backed) | `string` | `"premium"` | No |
| enable_rbac | Enable RBAC authorization (recommended) | `bool` | `true` | No |
| assign_rbac_to_current_user | Assign Key Vault Administrator to current deployer | `bool` | `true` | No |
| role_assignments | Map of role assignments on the Key Vault. Key is arbitrary. | `map(object({...}))` | `{}` | No |
| lock | Management lock configuration (CanNotDelete or ReadOnly) | `object({ kind = string, name = optional(string) })` | `null` | No |
| enabled_for_disk_encryption | Enable Azure Disk Encryption | `bool` | `false` | No |
| enabled_for_deployment | Enable VMs to retrieve certificates | `bool` | `false` | No |
| enabled_for_template_deployment | Enable ARM templates to retrieve secrets | `bool` | `false` | No |
| soft_delete_retention_days | Soft delete retention (7-90 days) | `number` | `90` | No |
| purge_protection_enabled | Enable purge protection (IRREVERSIBLE) | `bool` | `true` | No |
| public_network_access_enabled | Enable public network access | `bool` | `false` | No |
| network_acls | Network ACLs configuration | `object({...})` | `null` | No |
| tags | Tags to apply | `map(string)` | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| id | The Key Vault resource ID |
| name | The Key Vault name |
| uri | The Key Vault URI |
| tenant_id | The Key Vault tenant ID |
| resource | Complete Key Vault resource object |
