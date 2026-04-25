# AvdHostPool

Deploys an Azure Virtual Desktop **Host Pool** with optional auto-rotating **registration token** for session-host enrollment. Pooled (Win11 multi-session) and Personal pool types supported.

## Usage

### Standalone

```hcl
module "avd_pool" {
  source = "github.com/John6810/terraform-azurerm-modules//AvdHostPool?ref=AvdHostPool/v1.0.0"

  subscription_acronym = "avd"
  environment          = "nprd"
  region_code          = "weu"
  workload             = "pooled"
  location             = "westeurope"
  resource_group_name  = "rg-avd-nprd-weu-avd"

  type                     = "Pooled"
  load_balancer_type       = "BreadthFirst"
  maximum_sessions_allowed = 8
  preferred_app_group_type = "Desktop"
  start_vm_on_connect      = true
  public_network_access    = "Disabled"

  # Token rotated automatically every registration_expiration_hours
  create_registration_info       = true
  registration_expiration_hours  = 48

  tags = { Environment = "Non Production" }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/AvdHostPool"
}

dependency "rg_avd" {
  config_path = "../rg-avd"
}

inputs = {
  subscription_acronym = include.sub.locals.subscription_acronym
  environment          = include.root.inputs.environment
  region_code          = "weu"
  location             = "westeurope"
  workload             = "pooled"
  resource_group_name  = dependency.rg_avd.outputs.name

  type                     = "Pooled"
  maximum_sessions_allowed = 8
  start_vm_on_connect      = true
  public_network_access    = "Disabled"

  create_registration_info      = true
  registration_expiration_hours = 48

  tags = include.root.inputs.common_tags
}
```

## Naming Convention

`vdpool-{subscription_acronym}-{environment}-{region_code}-{workload}` — overridable via `var.name`.

## Required Inputs

| Name | Type | Description |
|---|---|---|
| `location` | `string` | Azure region (control plane: `westeurope` for GWC users) |
| `resource_group_name` | `string` | Resource group |

## Key Optional Inputs

| Name | Default | Description |
|---|---|---|
| `type` | `"Pooled"` | `"Pooled"` or `"Personal"` |
| `load_balancer_type` | `"BreadthFirst"` | Pooled load distribution: `BreadthFirst`, `DepthFirst`, or `Persistent` (Personal only) |
| `maximum_sessions_allowed` | `8` | Pooled only — concurrent sessions per session host |
| `preferred_app_group_type` | `"Desktop"` | `"Desktop"` or `"RailApplications"` |
| `start_vm_on_connect` | `true` | Wake deallocated session hosts on connection (pairs with Autoscale) |
| `public_network_access` | `"Enabled"` | Set `"Disabled"` + add a Private Endpoint for production |
| `create_registration_info` | `false` | Generate a token for session host DSC registration |
| `registration_expiration_hours` | `48` | Token lifetime; rotation happens via `time_rotating` and `replace_triggered_by` on each apply that elapses the window |

## Outputs

- `id` — Host pool resource ID
- `name` — Host pool name
- `registration_token` — `(sensitive)` token consumed by `AvdSessionHost.hostpool_registration_token`

## Notes

- The registration token **rotates** when the rotation window elapses and a `terraform apply` runs. Schedule a CI apply at least once per rotation period to keep the token fresh; otherwise new session hosts cannot enroll once the token expires.
- AVD control plane is **regional** (no GWC) — typical pattern is to deploy the pool/workspace/app group in `westeurope` while session hosts run in `germanywestcentral`.
- For private connectivity, set `public_network_access = "Disabled"` and add a Private Endpoint on the `connection` subresource.
