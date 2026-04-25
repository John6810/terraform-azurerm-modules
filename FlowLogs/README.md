# FlowLogs

Deploys **Azure VNet Flow Logs** with Traffic Analytics on one or more virtual networks. Uses the `azurerm_network_watcher_flow_log` resource pointed at a VNet (the modern API — NSG flow logs are deprecated and end-of-life on 2027-09-30).

## Usage

### Standalone

```hcl
module "flow_logs" {
  source = "github.com/John6810/terraform-azurerm-modules//FlowLogs?ref=FlowLogs/v1.0.0"

  subscription_acronym = "con"
  environment          = "nprd"
  region_code          = "gwc"
  location             = "germanywestcentral"
  resource_group_name  = "rg-con-nprd-gwc-network"

  network_watcher_name         = "nw-con-nprd-gwc"
  network_watcher_rg_name      = "rg-con-nprd-gwc-network"
  storage_account_id           = "/subscriptions/.../storageAccounts/stconnprdgwcflowlogs"
  log_analytics_workspace_id   = "/subscriptions/.../workspaces/law-mgm-nprd-gwc-01"
  log_analytics_workspace_guid = "82f9d847-335e-4441-adee-38a48dd8a613"

  retention_days  = 90
  traffic_analytics_interval_minutes = 60

  vnets = {
    nva = {
      id   = "/subscriptions/.../virtualNetworks/vnet-con-nprd-gwc-nva"
      name = "fl-con-nprd-gwc-nva"
    }
    shared = {
      id   = "/subscriptions/.../virtualNetworks/vnet-con-nprd-gwc-shared"
      name = "fl-con-nprd-gwc-shared"
    }
  }

  tags = { Environment = "Non Production" }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/FlowLogs"
}

dependency "nw"          { config_path = "../network-watcher" }
dependency "vnet_nva"    { config_path = "../network-shared" }
dependency "vnet_shared" { config_path = "../network-shared" }
dependency "storage"     { config_path = "../st-flowlogs" }
dependency "law"         { config_path = "${get_repo_root()}/landing-zone/platform/management/alz-management" }

inputs = {
  subscription_acronym = include.sub.locals.subscription_acronym
  environment          = include.root.inputs.environment
  region_code          = include.root.inputs.region_code
  location             = include.root.inputs.location

  network_watcher_name         = dependency.nw.outputs.name
  network_watcher_rg_name      = dependency.nw.outputs.resource_group_name
  storage_account_id           = dependency.storage.outputs.id
  log_analytics_workspace_id   = dependency.law.outputs.law_id
  log_analytics_workspace_guid = dependency.law.outputs.law_workspace_id

  vnets = {
    nva    = { id = dependency.vnet_nva.outputs.id,    name = "fl-${include.sub.locals.subscription_acronym}-${include.root.inputs.environment}-${include.root.inputs.region_code}-nva" }
    shared = { id = dependency.vnet_shared.outputs.id, name = "fl-${include.sub.locals.subscription_acronym}-${include.root.inputs.environment}-${include.root.inputs.region_code}-shared" }
  }

  tags = include.root.inputs.common_tags
}
```

## Required Inputs

| Name | Description |
|---|---|
| `location` | Region of the VNets |
| `network_watcher_name` / `network_watcher_rg_name` | Existing Network Watcher to attach flow logs to |
| `storage_account_id` | Target storage for raw flow log JSON (typically a dedicated `*flowlogs` storage account) |
| `log_analytics_workspace_id` / `log_analytics_workspace_guid` | LAW for Traffic Analytics |
| `vnets` | Map of VNet key → `{id, name}` to enable flow logs on |

## Key Optional Inputs

| Name | Default | Description |
|---|---|---|
| `enabled` | `true` | Master switch (per-VNet toggling via `vnets[*].enabled` if exposed) |
| `retention_days` | `90` | Raw log retention on the storage account (1-365) |
| `traffic_analytics_enabled` | `true` | Enable Traffic Analytics ingest into the LAW |
| `traffic_analytics_interval_minutes` | `60` | TA aggregation interval (10 or 60) |
| `version` | `2` | Flow log schema version (1 or 2; v2 is current) |
| `tags` | `{}` | Tags |

## Outputs

- `flow_log_ids` — Map VNet key → Flow log resource ID

## Notes

- **VNet flow logs (not NSG flow logs)**: this module uses the modern API targeting VNets directly. NSG flow logs reach end-of-life on **2027-09-30** and should be migrated.
- **Storage account constraints**: Microsoft Flow Logs service requires shared-key auth and writes from Microsoft-managed infrastructure (not from your VNet). The MCSB shared-key / VNet-rule / Private-Link checks on this storage account are by-design exempted (cf F-STOR-2 in the LZ's audit).
- **LAW guid vs id**: the resource needs both — `id` for ARM and `guid` (the immutable workspace identifier) for the flow log payload.
- **Cost**: storage scales with retention × traffic volume; Traffic Analytics adds an LAW ingestion cost. Tune `retention_days` and `traffic_analytics_interval_minutes` accordingly.
