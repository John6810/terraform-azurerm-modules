# AzureMonitorWorkspace

Creates an Azure Monitor Workspace (managed Prometheus metrics store) with an optional Private Endpoint for the `prometheusMetrics` subresource.

## Usage

### Standalone

```hcl
module "azure_monitor_workspace" {
  source = "github.com/John6810/terraform-azurerm-modules//AzureMonitorWorkspace?ref=AzureMonitorWorkspace/v1.0.0"

  subscription_acronym = "mgm"
  environment          = "prod"
  region_code          = "gwc"
  workload             = "01"
  location             = "germanywestcentral"
  resource_group_name  = "rg-mgm-prod-gwc-monitor"

  public_network_access_enabled = false
  subnet_id                     = "/subscriptions/.../subnets/snet-mgm-prod-gwc-pe"

  tags = { Environment = "Production" }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/AzureMonitorWorkspace"
}

inputs = {
  subscription_acronym          = include.sub.locals.subscription_acronym
  environment                   = include.root.inputs.environment
  region_code                   = include.root.inputs.region_code
  workload                      = "01"
  location                      = include.root.inputs.location
  resource_group_name           = dependency.rg.outputs.name
  public_network_access_enabled = false
  subnet_id                     = dependency.subnet.outputs.subnet_ids["snet-mgm-prod-gwc-pe"]
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
| name | Optional. Explicit name. If null, computed from naming components. | `string` | `null` | No |
| subscription_acronym | Subscription acronym (e.g. mgm, con) | `string` | `null` | No |
| environment | Environment (e.g. prod, nprd) | `string` | `null` | No |
| region_code | Region code (e.g. gwc, weu) | `string` | `null` | No |
| workload | Workload suffix | `string` | `"01"` | No |
| location | Azure region | `string` | -- | Yes |
| resource_group_name | Resource group name | `string` | -- | Yes |
| public_network_access_enabled | Whether public network access is enabled | `bool` | `false` | No |
| subnet_id | Subnet ID for the Private Endpoint. If null, no PE is created. | `string` | `null` | No |
| tags | Tags to apply | `map(string)` | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| id | The ID of the Azure Monitor Workspace |
| name | The name of the Azure Monitor Workspace |
| query_endpoint | The query endpoint for the Azure Monitor Workspace |
| default_data_collection_endpoint_id | The default Data Collection Endpoint ID |
| default_data_collection_rule_id | The default Data Collection Rule ID |
| resource | Complete Azure Monitor Workspace resource object |
| private_endpoint_id | The ID of the Private Endpoint (null if no PE) |
| private_endpoint_ip | The private IP address of the Private Endpoint |
