# Grafana

Deploys an Azure Managed Grafana instance with a dedicated resource group, a user-assigned managed identity, Azure Monitor Workspace integrations, and Entra ID RBAC group assignments (Admin, Editor, Viewer).

## Usage

### Standalone

```hcl
module "grafana" {
  source = "github.com/John6810/terraform-azurerm-modules//Grafana?ref=Grafana/v1.0.0"

  subscription_acronym = "mgm"
  environment          = "prod"
  region_code          = "gwc"
  location             = "germanywestcentral"

  grafana_sku           = "Standard"
  grafana_major_version = "11"

  azure_monitor_workspace_ids = [
    "/subscriptions/.../providers/Microsoft.Monitor/accounts/amw-mgm-prod-gwc-01"
  ]

  identity_role_assignments = {
    monitoring_reader = {
      scope                      = "/providers/Microsoft.Management/managementGroups/mg-lzr-prod"
      role_definition_id_or_name = "Monitoring Reader"
    }
  }

  grafana_admin_group_object_ids  = ["aaaaaaaa-0000-0000-0000-000000000001"]
  grafana_viewer_group_object_ids = ["aaaaaaaa-0000-0000-0000-000000000002"]

  tags = { Environment = "Production" }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/Grafana"
}

inputs = {
  subscription_acronym        = include.sub.locals.subscription_acronym
  environment                 = include.root.inputs.environment
  region_code                 = include.root.inputs.region_code
  location                    = include.root.inputs.location
  azure_monitor_workspace_ids = [dependency.amw.outputs.id]

  identity_role_assignments = {
    monitoring_reader = {
      scope                      = "/providers/Microsoft.Management/managementGroups/mg-lzr-${include.root.inputs.environment}"
      role_definition_id_or_name = "Monitoring Reader"
    }
    monitoring_data_reader = {
      scope                      = "/providers/Microsoft.Management/managementGroups/mg-lzr-${include.root.inputs.environment}"
      role_definition_id_or_name = "Monitoring Data Reader"
    }
  }

  grafana_admin_group_object_ids = ["aaaaaaaa-0000-0000-0000-000000000001"]
  tags                           = include.root.inputs.common_tags
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
| subscription_acronym | Subscription acronym (e.g. mgm) | `string` | -- | Yes |
| environment | Environment (e.g. prod, nprd) | `string` | -- | Yes |
| region_code | Region code (e.g. gwc) | `string` | -- | Yes |
| location | Azure region | `string` | -- | Yes |
| grafana_sku | Standard or Essential | `string` | `"Standard"` | No |
| grafana_major_version | Grafana major version | `string` | `"11"` | No |
| public_network_access_enabled | Enable public access | `bool` | `true` | No |
| zone_redundancy_enabled | Enable zone redundancy | `bool` | `false` | No |
| api_key_enabled | Enable API keys | `bool` | `false` | No |
| deterministic_outbound_ip_enabled | Enable deterministic outbound IPs | `bool` | `true` | No |
| azure_monitor_workspace_ids | AMW IDs to integrate | `list(string)` | `[]` | No |
| identity_role_assignments | Map of role assignments for the Grafana MI. Key is arbitrary. | `map(object({...}))` | `{}` | No |
| grafana_admin_group_object_ids | Entra ID group object IDs for Grafana Admin | `list(string)` | `[]` | No |
| grafana_editor_group_object_ids | Entra ID group object IDs for Grafana Editor | `list(string)` | `[]` | No |
| grafana_viewer_group_object_ids | Entra ID group object IDs for Grafana Viewer | `list(string)` | `[]` | No |
| tags | Tags | `map(string)` | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| resource_group_name | Grafana resource group name |
| grafana_id | Grafana instance ID |
| grafana_name | Grafana instance name |
| grafana_endpoint | Grafana endpoint URL |
| grafana_resource | Complete Grafana resource object |
| identity_id | Managed identity ID |
| identity_principal_id | Managed identity principal ID |
| identity_client_id | Managed identity client ID |

## ⚠️ Zone Redundancy is immutable

`zone_redundancy_enabled` cannot be changed after the Grafana instance is
created — Azure rejects the update. Flipping the value requires a full
**destroy + recreate**, which loses:

- Custom dashboards (export them via the Grafana API beforehand)
- Datasource links to LAW / AMW (must be re-linked)
- Entra ID RBAC group assignments (recreated by this module, but plan/apply
  ordering matters)
- Plugins, contact points, alert rules

**Decision matrix for this Landing Zone**:

| Environment | ZR | Rationale |
|---|---|---|
| **nprd** | `false` | Cost-saving on a consultation-only tool; break-glass via Azure Monitor portal during a zone incident is acceptable. Tracked as F-FIN-4 (closed by-design) in `audit-live-nprd.md` and exempted from the `Audit-ZoneResiliency` policy via `landing-zone/platform/management/policy-exemptions/grafana-zr-waiver`. |
| **prod** | `true` | Grafana is *most needed* during a zone incident (to visualize the affected resources). Set `zone_redundancy_enabled = true` at the **first apply** of the prod deployment — flipping later requires recreation. |

The module default is `true` to make prod safe-by-default; nprd callers
must explicitly opt into `false`.
