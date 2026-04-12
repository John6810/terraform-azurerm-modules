# Naming

Centralizes resource name generation for Azure Landing Zone deployments. Wraps the official `Azure/naming/azurerm` module for standard resource types and adds custom naming for Palo Alto resources and other types not covered upstream.

## Usage

### Standalone

```hcl
module "naming" {
  source = "github.com/John6810/terraform-azurerm-modules//Naming?ref=Naming/v1.0.0"

  prefix      = ["api"]
  suffix      = ["01"]
  environment = "prod"
  region      = "gwc"

  name_suffixes = ["trust", "untrust", "mgmt"]
}

# Access names
# module.naming.all_names["resource_group"]           → "rg-api-prod-gwc-01"
# module.naming.all_names["palo_alto_vm_series"]      → "api-palofw-prod-gwc-01"
# module.naming.built_names["palo_alto_interface"]["trust"] → "api-paloif-prod-gwc-01-trust"
# module.naming.azure_naming.key_vault.name_unique    → "kv-api-prod-gwc-01-xxxx"
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| azurerm | ~> 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| prefix | Prefix for all names (e.g. ["api"]) | `list(string)` | `[]` | No |
| suffix | Suffix for all names (e.g. ["01"]) | `list(string)` | `[]` | No |
| environment | Environment (dev, test, nprd, prod, dr, sandbox, lab) | `string` | `null` | No |
| region | Azure region short name (e.g. gwc, weu) | `string` | `null` | No |
| unique_seed | Seed for unique name generation | `string` | `""` | No |
| unique_length | Unique suffix length (1-8) | `number` | `4` | No |
| custom_resource_types | Additional custom resource types (key = type, value = short name) | `map(string)` | `{}` | No |
| name_suffixes | Suffixes for building name variations (e.g. ["trust", "untrust"]) | `list(string)` | `[]` | No |

## Outputs

| Name | Description |
|------|-------------|
| azure_naming | Full Azure naming module object (access any .resource_type.name) |
| all_names | Combined map of all names (Azure + custom) |
| custom_names | Custom resource names (sanitized) |
| storage_names | Storage-safe names (lowercase alphanumeric, max 24 chars) |
| built_names | Names with all name_suffixes applied (nested map) |
