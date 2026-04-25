# AvdScalingPlan

Deploys an AVD **Autoscale Plan** that controls session host VM lifecycle (start/stop/drain) on a schedule. Reduces compute costs by deallocating VMs during low-usage hours and waking them on demand or on a ramp-up schedule.

## Usage

### Standalone

```hcl
module "avd_scaling" {
  source = "github.com/John6810/terraform-azurerm-modules//AvdScalingPlan?ref=AvdScalingPlan/v1.0.0"

  subscription_acronym = "avd"
  environment          = "nprd"
  region_code          = "weu"
  workload             = "pooled"
  location             = "westeurope"
  resource_group_name  = "rg-avd-nprd-weu-avd"

  time_zone = "Romance Standard Time"

  schedule = {
    name                                 = "weekday"
    days_of_week                         = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
    ramp_up_start_time                   = "07:00"
    ramp_up_load_balancing_algorithm     = "BreadthFirst"
    ramp_up_minimum_hosts_percent        = 20
    ramp_up_capacity_threshold_percent   = 60
    peak_start_time                      = "09:00"
    peak_load_balancing_algorithm        = "BreadthFirst"
    ramp_down_start_time                 = "18:00"
    ramp_down_load_balancing_algorithm   = "DepthFirst"
    ramp_down_minimum_hosts_percent      = 10
    ramp_down_force_logoff_users         = false
    ramp_down_wait_time_minutes          = 30
    ramp_down_notification_message       = "You will be logged off in 30 minutes."
    ramp_down_capacity_threshold_percent = 90
    ramp_down_stop_hosts_when            = "ZeroSessions"
    off_peak_start_time                  = "20:00"
    off_peak_load_balancing_algorithm    = "DepthFirst"
  }

  host_pool_associations = {
    "vdpool-avd-nprd-weu-pooled" = {
      host_pool_id      = "/subscriptions/.../hostPools/vdpool-avd-nprd-weu-pooled"
      scaling_plan_enabled = true
    }
  }

  tags = { Environment = "Non Production" }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/AvdScalingPlan"
}

dependency "host_pool" { config_path = "../hp-avd" }

inputs = {
  subscription_acronym = include.sub.locals.subscription_acronym
  environment          = include.root.inputs.environment
  region_code          = "weu"
  location             = "westeurope"
  workload             = "pooled"
  resource_group_name  = "rg-${include.sub.locals.subscription_acronym}-${include.root.inputs.environment}-weu-avd"

  time_zone = "Romance Standard Time"

  schedule = { /* ... */ }

  host_pool_associations = {
    pooled = {
      host_pool_id         = dependency.host_pool.outputs.id
      scaling_plan_enabled = true
    }
  }

  tags = include.root.inputs.common_tags
}
```

## Naming Convention

`vdscaling-{subscription_acronym}-{environment}-{region_code}-{workload}` — overridable via `var.name`.

## Required Inputs

| Name | Description |
|---|---|
| `location` | Azure region (control plane region of the host pool) |
| `resource_group_name` | Resource group |
| `time_zone` | Windows time-zone name (e.g. `"Romance Standard Time"`, `"W. Europe Standard Time"`) |
| `schedule` | Schedule definition object (ramp-up / peak / ramp-down / off-peak phases) |
| `host_pool_associations` | Map of host-pool associations to attach the plan to |

## Key Optional Inputs

| Name | Default | Description |
|---|---|---|
| `description` | — | Plan description |
| `friendly_name` | — | Display name |
| `tags` | `{}` | Tags |

## Outputs

- `id` — Scaling plan resource ID
- `name` — Scaling plan name

## Notes

- **AVD Autoscale prerequisite**: the AVD service principal needs *Desktop Virtualization Power On Off Contributor* on the session host subscription. The repo deploys this via the `RbacAssignments` module.
- **start_vm_on_connect** must be enabled on the host pool (`AvdHostPool.start_vm_on_connect = true`) for ramp-up to wake deallocated VMs.
- For **Personal** pools, only a subset of fields are honored (no peak load balancing).
