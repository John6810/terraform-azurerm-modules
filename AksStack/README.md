# AksStack

Full AKS workload bundle in **one Terragrunt apply** — replaces 7 separate
deployments (`rg-aks`, `id-aks-cp`, `id-aks-kubelet`, `kv-{wl}`, `kv-key-etcd`,
`aks-*`, `rbac-*`) with a single composed module.

> **Composition strategy: wrapper (B2)** — AksStack does **not** inline
> resources. It calls the canonical child modules (`ResourceGroup`,
> `ManagedIdentity`, `KeyVault`, `KeyVault-Key`, `Aks`) via `git::` source
> URLs, so any fix to the child modules propagates here at the next ref bump.
> Trade-off: ~10s extra `terragrunt init` per fresh cache for the network
> fetch of 5 sub-modules, in exchange for zero drift and ~250 lines instead
> of ~700.
>
> This is a deliberate departure from the inline pattern used by
> `KeyVaultStack`, `NetworkStack`, `ResourceGroupSet`. Sprint 7 audit P0 #1
> selected option (c) "accept duplication + lint" for those — AksStack opts
> into option (b) "wrap canonical modules" because the duplication cost
> would be too high (5 modules × ~150 lines each).

## What it builds

| Resource | Count | Notes |
|---|---|---|
| Resource Group | 0–1 | Optional via `create_resource_group` |
| User Assigned Identity (Control Plane) | 1 | `id-{prefix}-aks-cp` |
| User Assigned Identity (Kubelet) | 1 | `id-{prefix}-aks-kubelet` |
| Key Vault (Premium, RBAC, private) | 1 | `kv-{prefix}-{kv_workload}{kv_suffix}` |
| KV Key (etcd CMK, RSA-2048, rotated) | 1 | `aks-etcd-key` |
| AKS Cluster | 1 | Private + Azure CNI Overlay + AAD RBAC + WI |
| User Node Pools | 0–N | via `var.user_node_pools` map |
| Diagnostic Setting | 0–1 | When `log_analytics_workspace_id` is set |
| Role Assignments | 4–N | KV admin setup, kubelet KV Crypto User, CP UAMI Network Contributor on subnet, kubelet AcrPull, optional cluster admin/user |

## Built-in Microsoft AKS best practices

- **Private cluster** (`private_cluster_enabled = true`)
- **Azure CNI Overlay** (efficient pod IP usage)
- **OIDC issuer + Workload Identity** (federated credentials for AAD-aware pods)
- **AAD RBAC + Azure RBAC for Kubernetes** (no local accounts)
- **KMS v2 etcd encryption** (CMK from this stack's KV)
- **Azure Policy add-on** + **Container Insights** + **Managed Prometheus**
- **Image Cleaner** (48h interval default)
- **Auto-upgrade stable** + **Node OS SecurityPatch**
- **Encryption at host** (system pool default-on; user pools opt-in via map)
- **Maintenance window** (configurable)
- **Multi-zone** (`["1", "2", "3"]`) for AZ redundancy

## Network primitives are external

`AksStack` does **not** create VNets, subnets, NSGs or route tables. Provision
those via [`NetworkStack`](../NetworkStack/) and pass:

- `node_subnet_id` — subnet for the node pools (must allow node–API and node–API service traffic)
- `api_server_subnet_id` — optional, for API Server VNet Integration

When `api_server_subnet_id` is set, **KMS v2 Private + VNet Integration must be
enabled out-of-band via `az aks update`** (azurerm v4 limitation, tracked in
[hashicorp/terraform-provider-azurerm#27640](https://github.com/hashicorp/terraform-provider-azurerm/issues/27640)).
The `output.post_deploy_az_cli_commands` exposes the exact commands to run.

## Usage — Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/AksStack"
}

dependency "rg" {
  config_path = "../resource-group"   # ResourceGroupSet output
}

dependency "network" {
  config_path = "../network"          # NetworkStack output
}

dependency "alz_management" {
  config_path = "${get_repo_root()}/landing-zone/platform/management/alz-management"
}

inputs = {
  subscription_acronym = include.sub.locals.subscription_acronym
  environment          = include.root.inputs.environment
  region_code          = include.root.inputs.region_code
  location             = include.root.inputs.location
  tenant_id            = include.root.locals.tenant_id

  # RG: use existing one created by ResourceGroupSet
  create_resource_group = false
  resource_group_name   = dependency.rg.outputs.names["aks"]

  # Network: use NetworkStack outputs
  node_subnet_id       = dependency.network.outputs.subnet_ids["aks"]
  api_server_subnet_id = dependency.network.outputs.subnet_ids["apiserver"]   # null = no API Server VNet integration

  # KV admins (SETUP-only — once etcd CMK is created, you can revoke)
  kv_admin_principal_ids = [
    "<aad-group-or-user-objectId-for-kv-bootstrap>",
  ]

  # Cluster sizing
  system_pool_vm_size  = "Standard_D4ds_v5"
  system_pool_node_count = 3

  user_node_pools = {
    user = {
      name                    = "user"
      vm_size                 = "Standard_D4ds_v5"
      min_count               = 3
      max_count               = 6
      enable_auto_scaling     = true
      labels                  = { workload = "apps" }
    }
  }

  # Maintenance (Sat 02-06 CET)
  maintenance_window = {
    day        = "Saturday"
    hour_start = 1   # UTC = CET - 1
    hour_end   = 5
  }

  # Cross-sub LAW for diagnostic settings + Defender
  log_analytics_workspace_id = dependency.alz_management.outputs.law_id

  # ACR pull (kubelet → AcrPull on each)
  acr_pull_target_ids = []

  # Cluster admins / users (env-aware via TG_ENV in caller-side locals)
  cluster_admin_principal_ids = ["<aad-group-objectid-for-aks-admin>"]
}
```

## Post-deploy steps

After `terragrunt apply`, when `api_server_subnet_id` is set:

```bash
# Read the commands from output
terragrunt output post_deploy_az_cli_commands

# Execute (one-time, then state is preserved by lifecycle ignore_changes)
az aks update --name <cluster> --resource-group <rg> \
  --enable-apiserver-vnet-integration \
  --apiserver-subnet-id <apiserver_subnet_id>

az aks update --name <cluster> --resource-group <rg> \
  --enable-azure-keyvault-kms \
  --azure-keyvault-kms-key-id <key_versionless_id> \
  --azure-keyvault-kms-key-vault-network-access Private \
  --azure-keyvault-kms-key-vault-resource-id <kv_id>
```

These are protected by `lifecycle.ignore_changes = [api_server_access_profile, key_management_service]` so subsequent applies do not revert them.

## Trade-offs vs. 7 separate deployments

| Pro | Contre |
|---|---|
| 1 deployment instead of 7 | Bigger blast radius (1 apply = full cluster + KV + IDs + RBAC) |
| Cross-resource invariants validated at plan time | State file size 7× larger |
| Onboarding new AKS workload = 1 file, ~50 lines | Selective destroy harder (need `state rm` to drop one piece) |
| Fewer dep-chain races at apply | Pre-existing 7-deployment setups need state migration to adopt |

For existing apimanager-style deployments, **don't migrate** — the 7-deployment pattern works. Use AksStack for **new AKS workloads**.

## Outputs

See [`output.tf`](output.tf). Key ones for downstream callers:

- `cluster_id` / `cluster_name` / `cluster_fqdn` / `node_resource_group_name`
- `kubelet_identity` / `control_plane_identity` (full UAMI objects)
- `key_vault_id` / `key_vault_name` / `etcd_key_id`
- `oidc_issuer_url` (for Workload Identity federation)
- `post_deploy_az_cli_commands` (runbook)
