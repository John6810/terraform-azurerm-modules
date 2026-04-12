# Ampls

Creates an Azure Monitor Private Link Scope (AMPLS), links scoped services (Log Analytics Workspace, Automation Account), and deploys a Private Endpoint with DNS zone group for secure Azure Monitor traffic.

## Usage

### Standalone

```hcl
module "ampls" {
  source = "github.com/John6810/terraform-azurerm-modules//Ampls?ref=Ampls/v1.0.0"

  ampls_name          = "ampls-mgm-prod-gwc-01"
  resource_group_name = "rg-mgm-prod-gwc-management"
  location            = "germanywestcentral"

  ingestion_access_mode = "PrivateOnly"
  query_access_mode     = "PrivateOnly"

  scoped_services = {
    law = { resource_id = "/subscriptions/.../workspaces/law-mgm-prod-gwc-01" }
    aa  = { resource_id = "/subscriptions/.../automationAccounts/aa-mgm-prod-gwc-01" }
  }

  subnet_id            = "/subscriptions/.../subnets/snet-mgm-prod-gwc-pe"
  private_dns_zone_ids = [
    "/subscriptions/.../privateDnsZones/privatelink.monitor.azure.com",
    "/subscriptions/.../privateDnsZones/privatelink.oms.opinsights.azure.com",
    "/subscriptions/.../privateDnsZones/privatelink.ods.opinsights.azure.com",
    "/subscriptions/.../privateDnsZones/privatelink.agentsvc.azure-automation.net"
  ]

  tags = { Environment = "Production" }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/Ampls"
}

inputs = {
  ampls_name          = "ampls-mgm-prod-gwc-01"
  resource_group_name = dependency.rg.outputs.name
  location            = include.root.inputs.location

  scoped_services = {
    law = { resource_id = dependency.alz_management.outputs.law_id }
    aa  = { resource_id = dependency.alz_management.outputs.automation_account_id }
  }

  subnet_id            = dependency.subnet.outputs.subnet_ids["snet-mgm-prod-gwc-pe"]
  private_dns_zone_ids = values(dependency.dns_zones.outputs.private_dns_zone_resource_ids)
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
| ampls_name | Name of the Azure Monitor Private Link Scope | `string` | -- | Yes |
| resource_group_name | Name of the resource group | `string` | -- | Yes |
| location | Azure region | `string` | -- | Yes |
| ingestion_access_mode | AMPLS ingestion access mode: Open or PrivateOnly | `string` | `"PrivateOnly"` | No |
| query_access_mode | AMPLS query access mode: Open or PrivateOnly | `string` | `"PrivateOnly"` | No |
| scoped_services | Map of services to link to the AMPLS (e.g. law, aa) | `map(object({ resource_id = string }))` | -- | Yes |
| subnet_id | Subnet ID for the private endpoint | `string` | -- | Yes |
| private_dns_zone_ids | List of private DNS zone IDs for the PE DNS zone group | `list(string)` | -- | Yes |
| tags | Tags to apply to all resources | `map(string)` | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| ampls_id | The ID of the Azure Monitor Private Link Scope |
| ampls_resource | Complete AMPLS resource object |
| private_endpoint_id | The ID of the AMPLS private endpoint |
| private_ip_address | The private IP address of the AMPLS private endpoint |
