# FinOpsHub

Deploys the Microsoft FinOps Toolkit Hub infrastructure: a dedicated resource group, ADLS Gen2 storage account with msexports/ingestion/config containers, Azure Data Explorer cluster, Data Factory with ETL pipeline, Event Grid for blob notifications, and RBAC assignments.

## Usage

### Standalone

```hcl
module "finops_hub" {
  source = "github.com/John6810/terraform-azurerm-modules//FinOpsHub?ref=FinOpsHub/v1.0.0"

  subscription_acronym = "mgm"
  environment          = "prod"
  region_code          = "gwc"
  location             = "germanywestcentral"

  storage_replication_type = "LRS"
  export_retention_days    = 30
  ingestion_retention_months = 13

  enable_data_explorer = true
  adx_sku_name         = "Dev(No SLA)_Standard_D11_v2"
  adx_sku_capacity     = 1

  tags = { Environment = "Production" }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/FinOpsHub"
}

inputs = {
  subscription_acronym = include.sub.locals.subscription_acronym
  environment          = include.root.inputs.environment
  region_code          = include.root.inputs.region_code
  location             = include.root.inputs.location
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
| subscription_acronym | Subscription acronym (e.g. mgm, con) | `string` | -- | Yes |
| environment | Environment (e.g. prod, nprd) | `string` | -- | Yes |
| region_code | Region code (e.g. gwc, weu) | `string` | -- | Yes |
| location | Azure region | `string` | -- | Yes |
| tags | Tags to apply to all resources | `map(string)` | `{}` | No |
| storage_replication_type | Replication type for the storage account (LRS, ZRS) | `string` | `"LRS"` | No |
| export_retention_days | Days to retain raw exports in msexports container (0 = delete after processing) | `number` | `0` | No |
| ingestion_retention_months | Months to retain ingested data in ingestion container | `number` | `13` | No |
| enable_data_explorer | Deploy Azure Data Explorer cluster and databases | `bool` | `true` | No |
| adx_sku_name | ADX cluster SKU name | `string` | `"Dev(No SLA)_Standard_D11_v2"` | No |
| adx_sku_capacity | ADX cluster node count (1 for dev, 2+ for prod) | `number` | `1` | No |
| adx_hot_cache_days | Days for ADX hot cache | `number` | `31` | No |
| adx_soft_delete_days | Days for ADX soft delete retention | `number` | `365` | No |
| cost_management_exports_principal_id | Principal ID of the Azure Cost Management Exports Service Principal (null = no role assignment) | `string` | `null` | No |
| enable_public_access | Enable public network access on storage and ADF | `bool` | `true` | No |

## Outputs

| Name | Description |
|------|-------------|
| resource | The FinOps Hub resource group object |
| resource_group_name | The name of the FinOps Hub resource group |
| resource_group_id | The ID of the FinOps Hub resource group |
| storage_account_id | The ID of the FinOps Hub storage account |
| storage_account_name | The name of the FinOps Hub storage account |
| adx_cluster_id | The ID of the ADX cluster |
| adx_cluster_uri | The URI of the ADX cluster |
| adx_cluster_name | The name of the ADX cluster |
| data_factory_id | The ID of the Data Factory |
| data_factory_name | The name of the Data Factory |
| data_factory_principal_id | The principal ID of the Data Factory managed identity |
| eventhub_namespace_id | The ID of the Event Hub Namespace |
| adx_ingestion_uri | The data ingestion URI of the ADX cluster |
