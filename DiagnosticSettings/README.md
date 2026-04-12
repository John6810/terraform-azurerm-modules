# DiagnosticSettings

Creates Azure Monitor Diagnostic Settings on multiple Azure resources, forwarding log and metric categories to Log Analytics, Storage Account, Event Hub, or marketplace partners.

## Usage

### Standalone

```hcl
module "diagnostic_settings" {
  source = "github.com/John6810/terraform-azurerm-modules//DiagnosticSettings?ref=DiagnosticSettings/v1.0.0"

  diagnostic_settings = {
    vnet = {
      name                       = "diag-vnet"
      target_resource_id         = "/subscriptions/.../virtualNetworks/vnet-api-prod-gwc-spoke"
      log_analytics_workspace_id = "/subscriptions/.../workspaces/law-mgm-prod-gwc-01"
      logs                       = ["VMProtectionAlerts"]
      metrics                    = ["AllMetrics"]
    }
    nsg_nodes = {
      name                       = "diag-nsg-nodes"
      target_resource_id         = "/subscriptions/.../networkSecurityGroups/nsg-api-prod-gwc-nodes"
      log_analytics_workspace_id = "/subscriptions/.../workspaces/law-mgm-prod-gwc-01"
      logs                       = ["NetworkSecurityGroupEvent", "NetworkSecurityGroupRuleCounter"]
    }
  }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/DiagnosticSettings"
}

inputs = {
  diagnostic_settings = {
    vnet = {
      name                       = "diag-vnet"
      target_resource_id         = dependency.vnet.outputs.id
      log_analytics_workspace_id = dependency.law.outputs.id
      logs                       = ["VMProtectionAlerts"]
      metrics                    = ["AllMetrics"]
    }
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| azurerm | ~> 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| diagnostic_settings | Map of Diagnostic Settings. Key is arbitrary. | `map(object({...}))` | -- | Yes |

### Diagnostic Setting Object

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| name | `string` | Yes | -- | Diagnostic setting name |
| target_resource_id | `string` | Yes | -- | Target Azure resource ID |
| logs | `list(string)` | No | `[]` | Log categories to enable |
| metrics | `list(string)` | No | `[]` | Metric categories to enable |
| log_analytics_workspace_id | `string` | No | -- | Log Analytics Workspace ID |
| storage_account_id | `string` | No | -- | Storage Account ID for archival |
| event_hub_authorization_rule_id | `string` | No | -- | Event Hub auth rule ID |
| event_hub_name | `string` | No | -- | Event Hub name |
| marketplace_partner_resource_id | `string` | No | -- | Marketplace partner ID |

At least one destination must be set.

## Outputs

| Name | Description |
|------|-------------|
| ids | Map of key => Diagnostic Setting ID |
| resources | Map of key => complete Diagnostic Setting object |
