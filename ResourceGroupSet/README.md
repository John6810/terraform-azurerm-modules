# ResourceGroupSet

Creates **N Azure Resource Groups in one apply**, each with its own optional management lock and role assignments. Designed as a **subscription-baseline** module: one Terragrunt deployment owns all the RGs of a subscription, and downstream modules consume the RG names/ids via `dependency`.

## Why this module exists

The single-RG `ResourceGroup` module is fine when a deployment owns exactly one RG. But for a fresh subscription baseline (`shc`, `apimanager`, `liferay`, ...) you typically want a handful of RGs created together (network, aks, aca, vm, shared, ...). Creating each one in its own Terragrunt directory is verbose; bundling them in this module keeps the baseline declarative.

> Could not be implemented as a wrapper that calls the `ResourceGroup` module: Terragrunt copies only the source folder into its module cache, so child-module references (`source = "../ResourceGroup"`) do not resolve. The resource blocks here mirror `ResourceGroup/main.tf` 1:1 with `for_each`. Keep them in sync if `ResourceGroup` evolves.

## Naming

`rg-{subscription_acronym}-{environment}-{region_code}-{workload}` — same convention as `ResourceGroup`. Override per-entry via `name`.

## Usage (Terragrunt)

```hcl
# landing-zone/corporate/shc/rg-shc-nprd-gwc/terragrunt.hcl
include "root" { path = find_in_parent_folders("root.hcl") }
include "sub"  { path = find_in_parent_folders("sub.hcl") }

terraform {
  source = "git::https://.../terraform-azurerm-modules.git//ResourceGroupSet?ref=vX.Y.Z"
}

inputs = {
  resource_groups = {
    network = {
      workload = "network"
      lock     = { kind = "CanNotDelete" }
    }
    aks    = { workload = "aks" }
    aca    = { workload = "aca" }
    vm     = { workload = "vm" }
    shared = { workload = "shared", lock = { kind = "CanNotDelete" } }
  }
}
```

Downstream consumer:

```hcl
# landing-zone/corporate/shc/nw-shc-nprd-gwc/terragrunt.hcl
dependency "rg" {
  config_path = "../rg-shc-nprd-gwc"
  mock_outputs = {
    names = { network = "rg-shc-nprd-gwc-network" }
    ids   = { network = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-shc-nprd-gwc-network" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

inputs = {
  resource_group_name = dependency.rg.outputs.names["network"]
}
```

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `subscription_acronym` | `string` | yes | 2-5 lowercase letters (mgm, con, idn, sec, shc, ...) |
| `environment` | `string` | yes | 2-4 lowercase letters (prod, nprd) — auto-injected by `root.hcl` |
| `region_code` | `string` | yes | 2-5 lowercase letters (gwc, weu) — auto-injected by `root.hcl` |
| `location` | `string` | yes | Azure region (e.g. `germanywestcentral`) |
| `resource_groups` | `map(object)` | yes | Map of RGs to create. Key is opaque, used for output lookup. See per-entry fields below. |
| `tags` | `map(string)` | no | Set-level tags merged into every RG. Per-RG `tags` override on conflict. `CreatedOn` is auto-added. |

### `resource_groups[*]` fields

| Field | Type | Required | Description |
|---|---|---|---|
| `workload` | `string` | yes | Workload name. Final RG name = `rg-{acr}-{env}-{region}-{workload}` |
| `name` | `string` | no | Explicit name override. Skips computed naming. |
| `tags` | `map(string)` | no | Per-RG tags merged on top of set-level `tags`. |
| `lock` | `object({ kind, name? })` | no | Management lock. `kind`: `CanNotDelete` or `ReadOnly`. |
| `role_assignments` | `map(object)` | no | Same shape as `ResourceGroup.role_assignments`. |

## Outputs

| Output | Description |
|---|---|
| `resource_groups` | `map({ id, name, location, tags })` keyed by input map key |
| `ids` | `map(string)` of RG IDs |
| `names` | `map(string)` of RG names |
| `resources` | Full `azurerm_resource_group` objects (advanced) |
