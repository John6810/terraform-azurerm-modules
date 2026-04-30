# AvdSessionHost

Deploys one or more **Windows session host VMs** for an AVD host pool. Each VM gets a NIC, system-assigned identity, optional Trusted Launch, and three extensions (Entra Join → AVD DSC → FSLogix registry config). Admin password is read from Key Vault.

## Usage

### Standalone

```hcl
module "avd_sh" {
  source = "github.com/John6810/terraform-azurerm-modules//AvdSessionHost?ref=AvdSessionHost/v1.0.0"

  subscription_acronym = "avd"
  environment          = "nprd"
  region_code          = "gwc"
  workload             = "sh"
  location             = "germanywestcentral"
  resource_group_name  = "rg-avd-nprd-gwc-sh"

  vm_count             = 2
  vm_size              = "Standard_D4s_v5"
  availability_zones   = ["1", "2", "3"]
  subnet_id            = "/subscriptions/.../subnets/snet-avd-nprd-gwc-sh"

  # Win11 24H2 multi-session — AHB activated via license_type
  license_type        = "Windows_Client"
  patch_mode          = "AutomaticByPlatform"
  enable_trusted_launch = true

  # Local admin password from Key Vault
  admin_password_kv_id        = "/subscriptions/.../vaults/kv-avd-nprd-gwc-001"
  admin_password_secret_name  = "sh-local-admin-password"

  # AVD enrollment
  hostpool_name                = "vdpool-avd-nprd-weu-pooled"
  hostpool_registration_token  = "<token from AvdHostPool>"

  # FSLogix profile share
  fslogix_vhd_location    = "\\\\stavdfslogix.file.core.windows.net\\profiles"
  fslogix_profile_size_mb = 30000

  tags = { Environment = "Non Production" }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/AvdSessionHost"
}

dependency "host_pool" { config_path = "../hp-avd" }
dependency "rg_sh"     { config_path = "../rg-sh" }
dependency "subnet"    { config_path = "../subnet-avd" }
dependency "kv"        { config_path = "../kv-avd" }
dependency "st_fslogix" { config_path = "../st-avd-fslogix" }

inputs = {
  subscription_acronym = include.sub.locals.subscription_acronym
  environment          = include.root.inputs.environment
  region_code          = include.root.inputs.region_code
  location             = include.root.inputs.location
  workload             = "sh"

  vm_count            = 2
  resource_group_name = dependency.rg_sh.outputs.name
  subnet_id           = dependency.subnet.outputs.subnet_ids["snet-avd-nprd-gwc-sh"]

  admin_password_kv_id = dependency.kv.outputs.id

  hostpool_name               = dependency.host_pool.outputs.name
  hostpool_registration_token = dependency.host_pool.outputs.registration_token

  fslogix_vhd_location = "\\\\${dependency.st_fslogix.outputs.name}.file.core.windows.net\\profiles"

  tags = include.root.inputs.common_tags
}
```

## Naming Convention

| Resource | Pattern |
|---|---|
| Azure VM | `vm-{subscription_acronym}-{environment}-{region_code}-{workload}-{NN}` |
| Computer name (NetBIOS, ≤15) | `{computer_name_prefix}{NN}` (default `avd{environment}{region_code}`) |
| NIC | `nic-{...}-{NN}` |

## Required Inputs

| Name | Description |
|---|---|
| `location` | Azure region |
| `resource_group_name` | Resource group |
| `subnet_id` | Session host subnet |
| `admin_password_kv_id` | Key Vault holding the local admin password |
| `hostpool_name` | AVD host pool name to register with |
| `hostpool_registration_token` | Token from `AvdHostPool` (sensitive) |
| `fslogix_vhd_location` | SMB UNC path to the FSLogix profile share |

## Key Optional Inputs

| Name | Default | Description |
|---|---|---|
| `vm_count` | `1` | Number of session host VMs |
| `vm_size` | `Standard_D4s_v5` | Min 4 vCPU recommended for Win11 multi-session |
| `image` | Win11 24H2 AVD multi-session | Marketplace image |
| `os_disk.ephemeral` | `true` | D4s_v5 has 150 GiB temp — fits 128 GiB ephemeral OS |
| `accelerated_networking_enabled` | `true` | SR-IOV. Disable only for VM sizes that don't support it |
| `availability_zones` | `["1","2","3"]` | Round-robin VM placement |
| `enable_trusted_launch` | `true` | vTPM + Secure Boot |
| `license_type` | `"Windows_Client"` | AHB / M365 entitlement (avoids paying full Windows compute price) |
| `patch_mode` | `"AutomaticByPlatform"` | Pairs with Azure Update Manager |
| `bypass_platform_safety_checks_on_user_schedule` | `true` | Honor a maintenance configuration |
| `hotpatching_enabled` | `false` | Win11 24H2+ multi-session, opt-in |

## ⚠️ Ephemeral OS × VM size

`os_disk.ephemeral = true` (default) requires the chosen `vm_size` to expose
a temp/resource disk large enough for the OS image (128 GiB by default). The
2-vCPU "s" variants of v3/v4/v5 only have ~75 GiB of temp storage, which
**cannot** host the ephemeral OS — `terraform plan` will block via a
precondition listing the affected sizes.

| Choose | When |
| --- | --- |
| `Standard_D4s_v5` (or larger 's') | Default for AVD multi-session |
| `Standard_D2ds_v5` / any 'ds' variant | Need 2 vCPUs but want ephemeral OS |
| `os_disk.ephemeral = false` | Need a 2-vCPU 's' variant; pay for managed OS disk |

## Outputs

- `vm_ids` / `vm_names` / `computer_names` / `principal_ids` / `private_ips` — maps keyed by VM index (`"01"`, `"02"`, …)

## Notes

- **AHB + multi-session**: `license_type = "Windows_Client"` is required to consume the M365 entitlement on Win11 multi-session. Default `"None"` causes a silent overpayment.
- **Patch orchestration**: with `patch_mode = "AutomaticByPlatform"` + `bypass_platform_safety_checks_on_user_schedule = true`, Azure Update Manager / a maintenance configuration drives the patch window. Pair with a `Microsoft.Maintenance/configurations` resource at the cluster scope.
- **Token freshness**: the `hostpool_registration_token` input is sensitive and short-lived. Re-apply this module whenever the host pool token rotates (`AvdHostPool` does this automatically via `time_rotating`).
- **DSC artifact**: the AVD DSC URL (`avd_dsc_artifact_url`) defaults to a Microsoft-hosted gallery artifact. Pin to a specific version for reproducible builds.
