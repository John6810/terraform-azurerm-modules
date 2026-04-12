# AlzManagement

Deploys the Azure Landing Zone management stack using the official `Azure/avm-ptn-alz-management/azurerm` module. Creates a Log Analytics Workspace, Automation Account, Data Collection Rules (Change Tracking, VM Insights, Defender SQL), Microsoft Sentinel, and User Assigned Managed Identities (LAW, AMA).

## Usage

### Standalone

```hcl
module "alz_management" {
  source = "github.com/John6810/terraform-azurerm-modules//AlzManagement?ref=AlzManagement/v1.0.0"

  subscription_acronym = "mgm"
  environment          = "prod"
  region_code          = "gwc"
  workload             = "01"
  location             = "germanywestcentral"

  create_resource_group  = true
  resource_group_workload = "management"

  log_ingestion_gb_per_day = 5
  log_daily_quota_gb       = 10
  log_retention_days       = 30

  tags = { Environment = "Production" }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/AlzManagement"
}

inputs = {
  subscription_acronym   = include.sub.locals.subscription_acronym
  environment            = include.root.inputs.environment
  region_code            = include.root.inputs.region_code
  workload               = "01"
  location               = include.root.inputs.location
  create_resource_group  = true
  log_ingestion_gb_per_day = 5
  log_daily_quota_gb       = 10
  log_retention_days       = 30
  tags                   = include.root.inputs.common_tags
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| azapi | ~> 2.4 |
| azurerm | ~> 4.0 |
| time | >= 0.9.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| subscription_acronym | Subscription acronym (e.g. mgm, con) | `string` | -- | Yes |
| environment | Environment (e.g. prod, nprd) | `string` | -- | Yes |
| region_code | Region code (e.g. gwc, weu) | `string` | -- | Yes |
| workload | Workload suffix for naming | `string` | `"01"` | No |
| location | Azure region | `string` | -- | Yes |
| resource_group_name | Resource group name. Required when create_resource_group = false. | `string` | `null` | No |
| create_resource_group | If true, creates the resource group inline. | `bool` | `false` | No |
| resource_group_workload | Workload name for RG naming when create_resource_group = true. | `string` | `"management"` | No |
| log_ingestion_gb_per_day | Expected log ingestion per day in GB. >100 = CapacityReservation SKU. | `number` | `5` | No |
| log_daily_quota_gb | Daily quota for log ingestion in GB | `number` | `10` | No |
| log_retention_days | Log Analytics retention in days | `number` | `30` | No |
| law_internet_ingestion_enabled | Enable internet ingestion on LAW. Set to false after Private Endpoints are deployed. | `bool` | `true` | No |
| law_internet_query_enabled | Enable internet query on LAW. Set to false after Private Endpoints are deployed. | `bool` | `true` | No |
| law_local_authentication_enabled | Allow local (shared key) authentication on LAW. Best practice: false to force Azure AD only. | `bool` | `false` | No |
| aa_public_network_access_enabled | Allow public network access on Automation Account. Set to false for AMPLS. | `bool` | `false` | No |
| enable_cmk | Enable Customer Managed Keys for encryption | `bool` | `false` | No |
| tags | Tags to apply to all resources | `map(string)` | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| resource | The complete ALZ Management module output object |
| law_id | The ID of the Log Analytics Workspace |
| law_name | The name of the Log Analytics Workspace |
| law_workspace_id | The Workspace ID (GUID) of the Log Analytics Workspace |
| automation_account_id | The ID of the Automation Account |
| automation_account_name | The name of the Automation Account |
| law_identity_id | The ID of the LAW User Assigned Identity |
| ama_identity_id | The ID of the AMA User Assigned Identity |
| resource_group_name | The name of the resource group |
| resource_group_id | The ID of the resource group (only when created inline) |
