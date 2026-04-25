# AvdWorkspace

Deploys an AVD **Workspace** — the user-facing entry point that aggregates application groups (Desktop and RemoteApp) and exposes them in the AVD client. One workspace per logical environment is typical.

## Usage

### Standalone

```hcl
module "avd_ws" {
  source = "github.com/John6810/terraform-azurerm-modules//AvdWorkspace?ref=AvdWorkspace/v1.0.0"

  subscription_acronym = "avd"
  environment          = "nprd"
  region_code          = "weu"
  workload             = "main"
  location             = "westeurope"
  resource_group_name  = "rg-avd-nprd-weu-avd"

  friendly_name = "AVD nprd"
  description   = "Non-prod AVD workspace"

  application_group_associations = {
    "vdag-avd-nprd-weu-desktop" = "/subscriptions/.../applicationGroups/vdag-avd-nprd-weu-desktop"
  }

  public_network_access_enabled = false

  tags = { Environment = "Non Production" }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/AvdWorkspace"
}

dependency "dag" { config_path = "../dag-avd" }

inputs = {
  subscription_acronym = include.sub.locals.subscription_acronym
  environment          = include.root.inputs.environment
  region_code          = "weu"
  location             = "westeurope"
  workload             = "main"
  resource_group_name  = "rg-${include.sub.locals.subscription_acronym}-${include.root.inputs.environment}-weu-avd"

  friendly_name = "AVD ${include.root.inputs.environment}"

  application_group_associations = {
    desktop = dependency.dag.outputs.id
  }

  public_network_access_enabled = false

  tags = include.root.inputs.common_tags
}
```

## Naming Convention

`vdws-{subscription_acronym}-{environment}-{region_code}-{workload}` — overridable via `var.name`.

## Required Inputs

| Name | Description |
|---|---|
| `location` | Azure region (control plane: `westeurope` for GWC users) |
| `resource_group_name` | Resource group |

## Key Optional Inputs

| Name | Default | Description |
|---|---|---|
| `friendly_name` | — | Display name shown in AVD clients |
| `description` | — | Long description |
| `application_group_associations` | `{}` | Map of application group name → resource ID to expose in this workspace |
| `public_network_access_enabled` | `false` | Set `false` and add a Private Endpoint on the `feed` subresource for production |
| `tags` | `{}` | Tags |

## Outputs

- `id` — Workspace resource ID
- `name` — Workspace name

## Notes

- A workspace exposes **application groups**, not host pools directly. Bind your Desktop and RemoteApp groups via `application_group_associations`.
- For private connectivity, add a Private Endpoint on the `feed` subresource and disable public network access.
- AVD control plane resources (workspace, host pool, app groups) are **regional** — a single workspace can aggregate app groups from multiple regions.
