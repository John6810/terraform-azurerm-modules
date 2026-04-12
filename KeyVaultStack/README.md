# KeyVaultStack

Deploys a complete Key Vault stack in a single module: dedicated Resource Group (with optional lock and RBAC), Key Vault (RBAC, purge protection, public access disabled), RBAC deployer assignment, and Private Endpoint with optional static IP and DNS zone group.

## Usage

### Standalone

```hcl
module "key_vault_stack" {
  source = "github.com/John6810/terraform-azurerm-modules//KeyVaultStack?ref=KeyVaultStack/v1.0.0"

  subscription_acronym = "api"
  environment          = "prod"
  region_code          = "gwc"
  workload             = "apim"
  location             = "germanywestcentral"

  subnet_id          = "/subscriptions/.../subnets/snet-api-prod-gwc-pe"
  private_dns_zone_ids = ["/subscriptions/.../privateDnsZones/privatelink.vaultcore.azure.net"]

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
  source = "${get_repo_root()}/modules/KeyVaultStack"
}

inputs = {
  subscription_acronym = include.sub.locals.subscription_acronym
  environment          = include.root.inputs.environment
  region_code          = include.root.inputs.region_code
  workload             = "kv"
  kv_suffix            = "002"
  location             = include.root.inputs.location
  subnet_id            = dependency.subnet.outputs.subnet_ids[include.sub.locals.networks.corp_apimanager.subnets.kv.name]

  assign_rbac_to_current_user   = false
  public_network_access_enabled = false

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
| subscription_acronym | Subscription acronym (e.g. api, mgm) | `string` | -- | Yes |
| environment | Environment (e.g. prod, nprd) | `string` | -- | Yes |
| region_code | Region code (e.g. gwc, weu) | `string` | -- | Yes |
| workload | Workload name. Keep short (KV max 24 chars). | `string` | -- | Yes |
| location | Azure region | `string` | -- | Yes |
| subnet_id | Subnet ID for the Key Vault Private Endpoint | `string` | -- | Yes |
| kv_suffix | Suffix for KV/PE name. If null, uses workload. | `string` | `null` | No |
| kv_name | Explicit Key Vault name (3-24 chars). If null, computed. | `string` | `null` | No |
| tenant_id | Azure AD tenant ID (auto-detected if null) | `string` | `null` | No |
| sku_name | SKU: standard or premium | `string` | `"premium"` | No |
| enable_rbac | Enable RBAC authorization | `bool` | `true` | No |
| assign_rbac_to_current_user | Assign KV Administrator to deployer | `bool` | `true` | No |
| enabled_for_disk_encryption | Enable Azure Disk Encryption | `bool` | `false` | No |
| enabled_for_deployment | Enable VMs to retrieve certificates | `bool` | `false` | No |
| enabled_for_template_deployment | Enable ARM templates to retrieve secrets | `bool` | `false` | No |
| soft_delete_retention_days | Soft delete retention (7-90 days) | `number` | `90` | No |
| purge_protection_enabled | Enable purge protection (IRREVERSIBLE) | `bool` | `true` | No |
| public_network_access_enabled | Enable public network access | `bool` | `false` | No |
| network_acls | Network ACLs configuration | `object({...})` | `null` | No |
| lock | Management lock on the RG (CanNotDelete or ReadOnly) | `object({ kind = string, name = optional(string) })` | `null` | No |
| role_assignments | Map of RBAC role assignments on the RG. Key is arbitrary. | `map(object({...}))` | `{}` | No |
| private_dns_zone_ids | Private DNS Zone IDs for the PE | `list(string)` | `null` | No |
| pe_private_ip_address | Static private IP for the PE | `string` | `null` | No |
| pe_custom_network_interface_name | Custom NIC name for the PE | `string` | `null` | No |
| tags | Tags to apply to all resources | `map(string)` | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| resource_group_name | The resource group name |
| resource_group_id | The resource group ID |
| key_vault_id | The Key Vault resource ID |
| key_vault_name | The Key Vault name |
| key_vault_uri | The Key Vault URI |
| key_vault_tenant_id | The Key Vault tenant ID |
| key_vault_resource | Complete Key Vault resource object |
| private_endpoint_id | The Private Endpoint resource ID |
| private_endpoint_name | The Private Endpoint name |
| private_endpoint_ip | The private IP of the PE |
| private_endpoint_connection_status | The PE connection status |
