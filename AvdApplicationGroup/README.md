# AvdApplicationGroup

Deploys an Azure Virtual Desktop **Application Group** (Desktop or RemoteApp) bound to a host pool. Application groups are the unit assigned to users/groups in AVD — they expose either the full desktop session or a curated set of published applications.

## Usage

### Standalone

```hcl
module "avd_app_group" {
  source = "github.com/John6810/terraform-azurerm-modules//AvdApplicationGroup?ref=AvdApplicationGroup/v1.0.0"

  subscription_acronym = "avd"
  environment          = "nprd"
  region_code          = "weu"
  workload             = "desktop"
  location             = "westeurope"
  resource_group_name  = "rg-avd-nprd-weu-avd"

  host_pool_id = "/subscriptions/.../hostPools/vdpool-avd-nprd-weu-pooled"
  type         = "Desktop" # or "RemoteApp"

  friendly_name = "AVD Desktop nprd"

  tags = { Environment = "Non Production" }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/AvdApplicationGroup"
}

dependency "host_pool" {
  config_path = "../hp-avd"
}

inputs = {
  subscription_acronym = include.sub.locals.subscription_acronym
  environment          = include.root.inputs.environment
  region_code          = "weu"
  location             = "westeurope"
  workload             = "desktop"
  resource_group_name  = "rg-${include.sub.locals.subscription_acronym}-${include.root.inputs.environment}-weu-avd"

  host_pool_id  = dependency.host_pool.outputs.id
  type          = "Desktop"
  friendly_name = "AVD Desktop ${include.root.inputs.environment}"

  tags = include.root.inputs.common_tags
}
```

## Naming Convention

`vdag-{subscription_acronym}-{environment}-{region_code}-{workload}` — overridable via `var.name`.

## Required Inputs

| Name | Type | Description |
|---|---|---|
| `location` | `string` | Azure region |
| `resource_group_name` | `string` | Resource group |
| `host_pool_id` | `string` | Host pool resource ID this app group binds to |

## Key Optional Inputs

| Name | Default | Description |
|---|---|---|
| `type` | `"Desktop"` | `"Desktop"` (full session) or `"RemoteApp"` (curated apps) |
| `friendly_name` | — | Display name shown in AVD clients |
| `description` | — | Long description |
| `tags` | `{}` | Resource tags |

## Outputs

- `id` — Application Group resource ID
- `name` — Application Group name

## Notes

- A **Desktop** app group is implicitly created with every host pool but can be replaced/customized.
- A pool can have multiple **RemoteApp** groups (each exposing a curated subset).
- Workspace association is handled separately by the `AvdWorkspace` module.
