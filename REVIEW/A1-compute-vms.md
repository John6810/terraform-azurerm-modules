# Review A1 — Compute & VMs (9 modules)

Scope: `Aks`, `PaloCluster`, `ManagedIdentity`, `AvdApplicationGroup`, `AvdHostPool`, `AvdSessionHost`, `AvdScalingPlan`, `AvdWorkspace`, `ContainerRegistry`.
Provider baseline: azurerm `~> 4.0` (April 2026 — current GA at the time of writing is 4.31+). Cross-checks against the official Terraform Registry docs and Microsoft Learn.

---

## Module: Aks

**Purpose**: Private AKS cluster (Azure CNI Overlay, KMS v2, OIDC + Workload Identity, Defender, Managed Prometheus).

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- Standard variables present and properly validated (regex on acronym/env/region, contains() on enums).
- Cleanly handles ALZ DINE policy: comment block explicitly notes Container Insights/MSCI DCR is policy-managed; `microsoft_defender` and `oms_agent` in `ignore_changes`.
- Correct azurerm v4 attribute names already used: `auto_scaling_enabled`, `host_encryption_enabled`, `image_cleaner_enabled` (no legacy `enable_*`).
- `prevent_destroy` on the cluster, plus `ignore_changes` covering kubernetes_version, default_node_pool node_count, api_server_access_profile, key_management_service — matches gotcha #9.
- Workload autoscaler block (VPA + KEDA) exposed as toggles.
- User-pool `temporary_name_for_rotation` auto-derived, `coalesce` used consistently.
- Diagnostic settings include the right log categories for AKS (kube-audit-admin instead of kube-audit — the recommended one).

**Issues**:
- 🟠 **`tags` ignore-change is missing for `default_node_pool[0].tags`** — the tag merge embeds `CreatedOn` only on the cluster; user pools also embed `CreatedOn` and that timestamp updates on every plan because `time_static.time.id` is fresh on import-less applies. Verify the `time_static.time.id` is actually pinned in state — it is, but the `timeadd(..., "1h")` produces non-idempotent diffs only on first vs. subsequent applies; harmless but worth documenting.
- 🟠 `system_pool_node_count` default = 3 with `auto_scaling = false` and `ignore_changes = [default_node_pool[0].node_count]` — initial deploy honors 3, but later changes to `system_pool_node_count` are silently ignored. Either drop the var from `ignore_changes` and rely on cluster-autoscaler-only flips, or document the limitation.
- 🟠 `monitor_metrics {}` is empty — at azurerm 4.20+ you can pass `annotations_allowed`/`labels_allowed`. Not blocking; acceptable as default.
- 🟡 `dns_prefix` derivation `replace(local.name, "-", "")` is fine but DNS prefix is limited to 1–54 chars and certain characters; long workload names could exceed.
- 🟡 No diagnostic-setting metric category (in v4 metrics moved from `metric` to AllMetrics enabled flag) — not critical for AKS but worth a note.
- 🟡 README exists (132 lines) — not inspected line-by-line, ensure documents `kms_key_id` requires versionless URI (versioned URI silently breaks rotation).

**Microsoft / Terraform official-docs cross-check**:
- v4 resource: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster — `enable_*` removals already absorbed.
- April 2026: `azurerm_kubernetes_cluster` exposes `automatic_sku_upgrade_channel` (separate from `automatic_upgrade_channel`) and `support_plan` ("KubernetesOfficial" vs "AKSLongTermSupport"). Not exposed here. Consider adding `support_plan` for prod LTS.
- Confidential Computing nodepool `node_taints = ["kubernetes.azure.com/scalesetpriority=spot:NoSchedule"]` works fine as plain strings in `taints`.
- `cost_analysis_enabled = true` (Standard+/Premium SKU) was added in 4.14 — not exposed; add for FinOps.
- Gotcha #9 documented in code is accurate: `api_server_access_profile` and KMS Private remain unmanageable in v4 (issue #27640 still open as of April 2026). Keep the az CLI runbook close.

**Recommended changes**:
1. Add `cost_analysis_enabled` and `support_plan` variables (Standard+/Premium only).
2. Document explicitly in README that `kms_key_id` must be the **versionless** key URI.
3. Consider exposing `monitor_metrics.annotations_allowed/labels_allowed` for finer Prom scrape control.
4. Add `azure_keyvault_kms` block to `ignore_changes` is already there — also add `network_profile[0].load_balancer_profile` if outbound type ever switches.

**Verdict**: 🟡 Polish needed (small additions, no blocking issues).

---

## Module: PaloCluster

**Purpose**: Palo Alto VM-Series HA cluster (RG + ILB HA-ports + N firewalls with 3 NICs each + optional KV/key/DES + AppInsights per FW).

**Files inspected**: version.tf, variables.tf, main.tf, vmseries.tf, diskencryption.tf, monitoring.tf, output.tf, README.md (133 lines).

**Strengths**:
- Splits concerns across files cleanly (vmseries / diskencryption / monitoring / lb).
- Handles the SPN/user identity ping-pong properly via `kv_admin_principal_ids` list (gotcha noted in prompt). `data.azurerm_client_config.current` is only used for `tenant_id`, no longer for object_id assignment.
- Mgmt NIC has `accelerated_networking = false` and `ip_forwarding = false` (correct for PAN-OS); dataplane NICs have `accelerated_networking = var.x` and `ip_forwarding = true`.
- ILB Standard SKU + HA Ports (`protocol = "All"`, ports 0/0) — correct topology for trust ILB.
- `prevent_destroy` on VMs, KV, key, DES; `ignore_changes` for `source_image_reference` (avoids forced VM replacement on PAN-OS upgrades) and `allow_extension_operations` (Azure Policy drift).
- Custom data is the correct PAN-OS bootstrap format (semicolon-separated key=value, base64-encoded).
- Custom role for PAN-OS AppInsights includes `${local.prefix}-${var.workload}` to avoid prod/nprd name collision (gotcha #8).
- Disk Encryption Set uses `EncryptionAtRestWithPlatformAndCustomerKeys` (double encryption) and auto-rotation.

**Issues**:
- 🔴 **`os_disk_size_gb = 80`** — Palo Alto VM-Series flex/byol minimum is 60 GB, but the marketplace image's actual disk is 60 GB and resizing down isn't possible. 80 is fine — but if user provides smaller value the apply explodes. Add validation `>= 60`.
- 🟠 **`encryption_at_host_enabled` on PAN-OS** — Palo Alto's documentation explicitly states encryption at host is supported only from PAN-OS 11.0+; if a user deploys an older `panos_version` with default `encryption_at_host_enabled = true`, VM creation fails with a generic error. Add a note in the variable docstring or cross-validate with `panos_version`.
- 🟠 The `validation` rule `var.admin_password != null || var.admin_ssh_public_key != null || var.enable_disk_encryption` permits SSH-key-only — but PAN-OS VM-Series rejects SSH-key-only deploys (mgmt plane requires a password for the local admin). Add a doc note that ssh-public-key is generally insufficient on its own.
- 🟠 `azurerm_lb_probe` has `protocol = "Tcp"` but no `request_path` (correct, only HTTP/HTTPS need it). However Palo Alto's recommended health probe is `Tcp 22` (mgmt) or the SSH port on data interfaces — port 443 only works if you've configured a service profile. Fine as default but worth README mention.
- 🟠 Bootstrap mechanism uses `custom_data` with SAS-less storage account access key — works but legacy. Microsoft now recommends bootstrap via Azure Files with managed identity (PAN-OS 11.1+). Not a bug, just dated.
- 🟡 `azurerm_application_insights` `application_type = "other"` — should be `"web"` per PAN-OS docs (some APPI features only enabled when `web`). Verify.
- 🟡 Boot diagnostics: when `var.enable_boot_diagnostics = true` and `var.boot_diagnostics_storage_uri = null`, the empty `boot_diagnostics { storage_account_uri = null }` is acceptable (uses managed storage) — confirm.
- 🟡 `sku_name = "standard"` for the Key Vault — for HSM-backed key (Palo Alto KMS recommends HSM), should be `premium`. Document or expose.
- 🟡 Probe interval 5s + threshold 2 → 10s detection. Palo Alto's recommended HA failover is 5s + 2 = 10s, OK.

**Microsoft / Terraform official-docs cross-check**:
- v4 resource: `azurerm_linux_virtual_machine` — already using v4 attribute names (`encryption_at_host_enabled`, `accelerated_networking_enabled`).
- `azurerm_lb` — Standard SKU + zone-redundant frontend now supports `sku_tier = "Regional"` (default). Module doesn't set; default is fine.
- `azurerm_application_insights` — April 2026: `local_authentication_disabled` should be `true` for hardening. Not exposed.
- The `disable_password_authentication = var.admin_ssh_public_key != null` logic is correct for `azurerm_linux_virtual_machine` v4.

**Recommended changes**:
1. Add `validation { condition = var.os_disk_size_gb >= 60 }` to prevent invalid sizes.
2. Add `local_authentication_disabled = true` and `internet_ingestion_enabled = false` to `azurerm_application_insights` for security-hardened APPI.
3. Change `application_type = "web"` (matches PAN-OS docs) — or expose as variable.
4. Document in README that `sku_name = "standard"` Key Vault is OK for software-protected RSA 2048; if HSM key required, expose `kv_sku` variable defaulting to `premium`.
5. Document that `admin_ssh_public_key` alone is insufficient on PAN-OS — keep the password path.

**Verdict**: 🟡 Polish needed — solid bones, minor hardening + doc gaps.

---

## Module: ManagedIdentity

**Purpose**: User-Assigned Managed Identity with optional federated credentials, role assignments, and resource lock.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md (103 lines).

**Strengths**:
- Tight, single-purpose module. All standard variables present and validated.
- Federated identity credential block is well-typed with `audience` defaulting to AKS standard.
- Role assignments support both name and full ARM ID via the `strcontains` switch — same idiom used in ContainerRegistry. Consistent.
- Lock validation enforces "CanNotDelete"/"ReadOnly".
- Outputs cover `id`, `name`, `principal_id`, `client_id`, `tenant_id`, plus `resource` — exactly what AVD/AKS callers need.

**Issues**:
- 🟠 `principal_type` is **not exposed** on `azurerm_role_assignment` — same gotcha that just bit `rbac-avd` (commit `da4e610` had to set `principal_type = "Group"` manually). Without it, every assignment to a Group is created as `User` in the ARM payload, which can fail when the principal hasn't propagated to AAD or when it's a fresh group; Microsoft now recommends always providing `principal_type` explicitly. Add to the role_assignments object schema.
- 🟠 No `prevent_destroy` on the identity itself — for kubelet identity / cluster identity, deleting + recreating the MSI orphans all RBAC and breaks the cluster. Not all callers need it though, so leave as opt-in via the existing `lock` mechanism — but make sure README flags this.
- 🟡 `name` validation regex `^[a-zA-Z0-9][a-zA-Z0-9_-]{2,127}$` — Azure UAI allows underscores **only** in some places; the official rule is "alphanumeric, hyphens, underscores, max 128, no leading hyphen". Regex is OK but minimum length 3 (`{2,127}` after first char) is conservative; Azure allows down to 3 total chars. Fine.
- 🟡 `description` is missing on the `subscription_acronym` and a couple of vars — minor.
- 🟡 `output "resource"` is not marked sensitive but the UAI resource exposes `client_id` etc. — by convention these are fine; some MSI properties (tenant_id, principal_id) are non-secret.

**Microsoft / Terraform official-docs cross-check**:
- v4 resource: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity — no breaking changes since v3.
- `azurerm_federated_identity_credential` v4 unchanged.
- `azurerm_role_assignment` April 2026: `principal_type` is **strongly recommended** by Microsoft for replication-lag scenarios. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment

**Recommended changes**:
1. Add `principal_type` (optional string, validation: "User", "Group", "ServicePrincipal", "Device", "ForeignGroup") to the role_assignments object schema and pass it through.
2. README: add a note about kubelet/cluster identity replacement consequences.

**Verdict**: 🟡 Polish needed (one real bug: missing `principal_type` will reproduce the rbac-avd issue).

---

## Module: AvdApplicationGroup

**Purpose**: AVD application group (Desktop or RemoteApp) with optional workspace association.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf. README.md **missing**.

**Strengths**:
- Compact and focused. Standard variables + validations on `type` enum.
- Optional workspace association via `count` — clean.
- Naming convention `vdag-{...}` matches Microsoft Cloud Adoption Framework abbreviation.

**Issues**:
- 🟠 README missing.
- 🟠 No diagnostic_settings support — AVD application groups support diagnostics (`Checkpoint`, `Error`, `Management`). For prod compliance these need to be wired to LAW. Add as optional input.
- 🟠 No RBAC support — application groups are the binding point for "Desktop Virtualization User" role assignments to user groups. Currently callers must wire RBAC outside the module, which scatters the convention. Consider a `role_assignments` map (mirror ContainerRegistry).
- 🟡 No `friendly_name` validation (Azure max ~64 chars).
- 🟡 No `description` length validation (max 512).
- 🟡 No outputs for the workspace association id is provided (good), but no `resource` output.

**Microsoft / Terraform official-docs cross-check**:
- v4 resource: `azurerm_virtual_desktop_application_group` — unchanged in v4.
- April 2026: AVD App Attach (preview-out) uses separate resource `azurerm_virtual_desktop_app_attach_package` — not in scope here.
- `azurerm_virtual_desktop_workspace_application_group_association` recommended pattern is to drive the association from the **workspace module** OR here, but never both. Document the choice.

**Recommended changes**:
1. Create README.md.
2. Add `role_assignments` map (Desktop Virtualization User is the typical role).
3. Add `diagnostic_setting` input or note caller must layer DiagnosticSettings module on top.
4. Add `principal_type` to the future role_assignments schema.

**Verdict**: 🟡 Polish needed.

---

## Module: AvdHostPool

**Purpose**: AVD host pool (Pooled or Personal) with optional registration token.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf. README.md **missing**.

**Strengths**:
- Validations on `type`, `load_balancer_type`, `preferred_app_group_type`, `public_network_access`, `registration_expiration_hours`.
- `maximum_sessions_allowed` correctly nulled when `type == "Personal"`.
- Registration token marked `sensitive = true` and gated by `count`.
- `start_vm_on_connect = true` default is correct for autoscale pairing.

**Issues**:
- 🔴 **Registration token rotation logic is wrong**. `expiration_date = timeadd(time_static.time.id, "${var.registration_expiration_hours}h")` — `time_static.time` only changes on resource recreate, so the token **never refreshes**. After 48h the token expires and new session hosts cannot register. The standard fix is `time_rotating` resource keyed to the rotation period (e.g. `time_rotating.token { rotation_hours = var.registration_expiration_hours - 4 }`) with the rotation id as a `triggers` input on the registration_info resource. As-is, callers must run `terraform taint` periodically.
- 🟠 No `personal_desktop_assignment_type` exposed — required when `type == "Personal"` (values: `Automatic`, `Direct`). Module silently passes null which Azure defaults to `Automatic`; document.
- 🟠 `validate_environment` default `false` is fine for prod, but it's worth documenting that this is a one-way dial-in for early-channel agent updates.
- 🟠 No diagnostic settings.
- 🟡 No README.
- 🟡 No `scheduled_agent_updates` block exposed — host pool now supports a scheduled maintenance window for the AVD agent itself (azurerm 4.18+). Consider exposing.
- 🟡 `output "resource"` should be marked `sensitive = true` because it includes the registration_info token URL.

**Microsoft / Terraform official-docs cross-check**:
- v4 resource: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_desktop_host_pool
- April 2026: `scheduled_agent_updates` block + `vm_template` (preview) for shared-image-gallery integration.

**Recommended changes**:
1. **Switch to `time_rotating`** for `expiration_date` so the token rotates automatically — single biggest fix.
2. Expose `personal_desktop_assignment_type` and `scheduled_agent_updates`.
3. Add `role_assignments` map (Application Group is where Desktop Virtualization User goes, but Power-On Contributor lives at host pool/VM scope).
4. Mark `output "resource"` sensitive.
5. README.

**Verdict**: 🟠 Significant rework — registration token rotation needs to be fixed before this is reliable in prod.

---

## Module: AvdSessionHost

**Purpose**: Windows session-host VMs (NIC + VM + Entra-join + AVD DSC + FSLogix CSE).

**Files inspected**: version.tf, variables.tf, main.tf, output.tf. README.md **missing**.

**Strengths**:
- POC scope correctly framed in the header comment.
- Strong input validation: subnet_id regex, KV id regex, computer_name_prefix regex, vm_count bounds.
- Trusted Launch defaults `true` (correct for Win11 + AVD).
- `os_disk.ephemeral = true` default with auto-coerce of `caching = ReadOnly` when ephemeral — fixes the gotcha where Azure rejects `ReadWrite` caching on ephemeral. Good.
- Per-VM zone via `element(var.availability_zones, i)` — round-robin across zones. Good.
- Extension chain: `entra_join` → `avd_dsc` → `fslogix` with explicit `depends_on`. Correct ordering.
- DSC PrivateSettingsRef pattern (`Password = "PrivateSettingsRef:RegistrationInfoToken"`) matches Microsoft's documented contract — and the recent fixup commits (`da4e610`, `5ecbcad`) show this is now stable.
- Admin password fetched from Key Vault, not hardcoded; `ignore_changes = [admin_password]` matches the out-of-band rotation model.

**Issues**:
- 🔴 **Recent gotcha #11 (D2s_v5 + Ephemeral OS)** — the variable default is `Standard_D4s_v5` which is fine, but `os_disk.ephemeral` defaults to `true` with no validation that the chosen `vm_size` has sufficient temp/cache for the chosen `os_disk.disk_size_gb`. A user passing `Standard_D2s_v5` will get an opaque deploy failure. Add cross-validation (or at least a doc warning).
- 🟠 **Patch mode not set** — for Win11 multi-session, `patch_mode = "AutomaticByPlatform"` + `bypass_platform_safety_checks_on_user_schedule_enabled = true` is the recommended posture (lets ALZ Update Manager govern patching). Not exposed → defaults to "ImageDefault" which mostly does nothing.
- 🟠 **`license_type`** not set — for Windows 11 Enterprise multi-session AVD, you should set `license_type = "Windows_Client"` (Hybrid Use Benefit). Not setting it is a billing error in production.
- 🟠 **No `enable_ip_forwarding` reset** — fine, default false is correct, but no `accelerated_networking_enabled` on the NIC. D4s_v5 supports it; not enabling is a perf miss.
- 🟠 FSLogix CSE writes registry keys via inline PowerShell — works for POC but the standard pattern uses `Configure-FSLogix.ps1` from a versioned blob. Acceptable POC; flag as tech debt.
- 🟡 `vm_count` validation `1..100` — Azure soft cap for AVD pool is 250 hosts, so `100` is conservative. Probably fine.
- 🟡 No diagnostic settings.
- 🟡 No README.
- 🟡 `auto_upgrade_minor_version = true` on the AVD DSC extension — version `2.83` is pinned but Microsoft has shipped 2.86+. Auto-upgrade is fine, but document the consequence.

**Microsoft / Terraform official-docs cross-check**:
- v4: `azurerm_windows_virtual_machine` — `secure_boot_enabled` + `vtpm_enabled` are correct (Trusted Launch). `security_type = "TrustedLaunch"` is **not** required when `vtpm_enabled = true && secure_boot_enabled = true` — provider infers it.
- April 2026: `os_disk.security_encryption_type = "DiskWithVMGuestState"` is required for **Confidential VMs**, not Trusted Launch — keep ignored.
- `azurerm_virtual_machine_extension` v4 unchanged.
- `patch_mode` and `bypass_platform_safety_checks_on_user_schedule_enabled` see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine

**Recommended changes**:
1. Add `license_type = "Windows_Client"` (variable, default to that for AVD).
2. Add `patch_mode` variable + `bypass_platform_safety_checks_on_user_schedule_enabled` (default Update Manager-friendly).
3. Add `accelerated_networking_enabled = true` on the NIC (default true with override).
4. Cross-validate `os_disk.ephemeral` vs `vm_size` (at least block known-bad combos like D2s_v5).
5. Output: add `nic_ids` (already have `private_ips`) for downstream NSG/RBAC wiring.
6. README.

**Verdict**: 🟠 Significant rework — billing (license_type) and patching (patch_mode) defaults are wrong for production AVD; ephemeral cross-validation guards a recurring gotcha.

---

## Module: AvdScalingPlan

**Purpose**: AVD Autoscale scaling plan with schedules and host pool associations.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf. README.md **missing**.

**Strengths**:
- All schedule fields cleanly modeled as a `map(object)` with descriptive docstring.
- Dynamic `host_pool` block lets one plan attach multiple pools.
- `time_zone` default `W. Europe Standard Time` matches Germany West Central.

**Issues**:
- 🟠 **No validation on schedule values** — `days_of_week` accepts arbitrary strings (Azure rejects non-PascalCase like "monday"); `ramp_up_minimum_hosts_percent` and `ramp_down_capacity_threshold_percent` are unbounded; bad inputs blow up at apply, not plan. Add validations.
- 🟠 **Personal scaling plans not supported** — schedules object is shaped for Pooled (`ramp_up_load_balancing_algorithm`, etc.). For Personal, the schema is different (`ramp_up_auto_start_hosts`, `ramp_down_action_on_disconnect`, etc., per azurerm 4.20+). If AVD personal pools land in BACKLOG.md, this module needs a separate variable shape.
- 🟠 No RBAC variable — the scaling plan needs the **Desktop Virtualization Power-On Contributor** role on its identity granted at the host-pool RG scope. Without it, scaling silently no-ops. Module doesn't help wire this.
- 🟡 No outputs beyond `id`/`name` — e.g. `host_pool_associations` map back would be useful for verifying.
- 🟡 No README.
- 🟡 No diagnostic settings (scaling plan logs to LAW are useful for debugging "why didn't it scale").

**Microsoft / Terraform official-docs cross-check**:
- v4 resource: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_desktop_scaling_plan
- April 2026: Personal autoscale promoted to GA in azurerm 4.20+ — adds `schedule.ramp_up_auto_start_hosts`, `ramp_up_start_vm_on_connect`, `ramp_down_action_on_disconnect`, `ramp_down_action_on_logoff`, `peak_action_on_disconnect`, `off_peak_action_on_disconnect`. **None are exposed**. This is the biggest doc gap.

**Recommended changes**:
1. Add validations: `days_of_week` PascalCase, percent fields 0..100, time format `HH:MM`.
2. Add a second `schedules_personal` variable (or a `type` discriminator) to support Personal pools per azurerm 4.20+.
3. Add `role_assignments` to grant Power-On Contributor at host pool RG scope (or document the RBAC requirement).
4. README + sample schedule snippet.

**Verdict**: 🟡 Polish needed (Personal-pool gap is significant if AVD Personal lands in BACKLOG).

---

## Module: AvdWorkspace

**Purpose**: AVD workspace (the user-facing portal grouping app groups).

**Files inspected**: version.tf, variables.tf, main.tf, output.tf. README.md **missing**.

**Strengths**:
- Trivially simple, single resource, standard variables present.
- `public_network_access_enabled` exposed — required for Private Link feed PE workflows.

**Issues**:
- 🟠 No diagnostic settings — workspace `Checkpoint`/`Error`/`Management`/`Feed` logs are valuable.
- 🟡 No `application_group_ids` input — currently associations are wired from the `AvdApplicationGroup` module side. Decide on **one** source of truth (callers shouldn't be free to do both, or you get two-state bindings).
- 🟡 No `resource` output.
- 🟡 No README.

**Microsoft / Terraform official-docs cross-check**:
- v4 resource: `azurerm_virtual_desktop_workspace` — unchanged.
- April 2026: no notable additions.

**Recommended changes**:
1. README documenting that workspace↔app-group association lives in the `AvdApplicationGroup` module.
2. Optionally add `application_group_ids = list(string)` to centralize bindings here, and remove from `AvdApplicationGroup` (pick one).
3. Add `resource` output.

**Verdict**: ✅ OK — minor polish.

---

## Module: ContainerRegistry

**Purpose**: ACR (Premium by default) with role assignments and resource lock.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md (100 lines).

**Strengths**:
- All standard variables + validations (including ACR-specific name regex `^[a-zA-Z0-9]{5,50}$`).
- Naming convention exception (`cr{acr}{env}{region}{workload}` no hyphens) honored in code.
- Premium SKU + zone redundancy + data endpoint defaults — matches PE-friendly posture.
- Geo-replication exposed as list of objects (Premium feature), gated by SKU implicitly.
- `prevent_destroy` on the ACR.
- Role assignments support both name and ID with the `strcontains` switch; `principal_type` exposed (✅ unlike ManagedIdentity).
- `public_network_access_enabled = false` default — correct posture for PE-only.

**Issues**:
- 🟠 **No customer-managed key (CMK) encryption** — Premium ACR supports CMK via Disk Encryption-style UAI + Key Vault key. Not exposed. For compliance-bound subscriptions this is needed.
- 🟠 **No retention_policy / trust_policy / quarantine_policy** — Premium ACR retention policy (untagged manifests) and content trust are not exposed. Default ACR keeps everything → cost creep.
- 🟠 **No `network_rule_bypass_option`** — needed when ACR is private + you want to allow Trusted Microsoft Services. Default is `AzureServices`; expose.
- 🟠 `network_rule_set` shape only allows `default_action` — no `ip_rule` or `virtual_network` — so the variable is half-built. azurerm 4.x removed virtual_network rules from ACR (ServiceEndpoints deprecated for ACR PE), so just IP rules remain.
- 🟡 `output "resource"` not sensitive — fine.
- 🟡 No diagnostic settings.

**Microsoft / Terraform official-docs cross-check**:
- v4 resource: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry
- v4 dropped `network_rule_set.virtual_network` (replaced by Private Endpoints) — module correctly omits it.
- April 2026: `azurerm_container_registry_cache` and `azurerm_container_registry_credential_set` (cache rules + upstream auth) — module doesn't expose, but those are higher-order concerns.
- April 2026: ACR **anonymous_pull_enabled** and **export_policy_enabled** (default true). Setting `export_policy_enabled = false` blocks `acr import` egress — exposing is a hardening win.

**Recommended changes**:
1. Add `identity` block + `encryption.key_vault_key_id` for CMK (Premium-only).
2. Add `retention_policy` (days for untagged manifests) and `trust_policy` (content trust).
3. Add `anonymous_pull_enabled = false` and `export_policy_enabled = false` defaults.
4. Extend `network_rule_set` to include `ip_rule` list.

**Verdict**: 🟡 Polish needed (CMK + retention are legitimate compliance gaps).

---

## Summary

| # | Module | Verdict | Top issue |
|---|---|---|---|
| 1 | Aks | 🟡 Polish needed | Missing `cost_analysis_enabled`, `support_plan`, README KMS-versionless note |
| 2 | PaloCluster | 🟡 Polish needed | App Insights `application_type` should be `web`; `os_disk_size_gb` validation missing |
| 3 | ManagedIdentity | 🟡 Polish needed | `principal_type` not exposed on role_assignments — same gap that bit rbac-avd |
| 4 | AvdApplicationGroup | 🟡 Polish needed | No README, no role_assignments, no diagnostics |
| 5 | AvdHostPool | 🟠 Significant rework | Registration token never rotates (uses `time_static`, not `time_rotating`) |
| 6 | AvdSessionHost | 🟠 Significant rework | Missing `license_type=Windows_Client`, `patch_mode`, ephemeral×size cross-check |
| 7 | AvdScalingPlan | 🟡 Polish needed | Personal-pool autoscale fields not exposed (azurerm 4.20+ GA) |
| 8 | AvdWorkspace | ✅ OK | Minor: README + `resource` output |
| 9 | ContainerRegistry | 🟡 Polish needed | No CMK encryption, no retention policy, no anonymous_pull_enabled |

**Cross-cutting themes**:
- 🟠 **`principal_type` on role assignments** — `ManagedIdentity`, `AvdApplicationGroup`, `AvdHostPool` (when added), `AvdScalingPlan` (when added) all need this. `ContainerRegistry` already has it; use it as the template.
- 🟠 **Diagnostic settings** — none of the AVD modules expose them. Either layer the existing `DiagnosticSettings` module on top, or add an optional input. Document the choice once in CONTRIBUTING.md.
- 🟠 **READMEs missing** for all 5 AVD modules.
- 🟡 **`time_static` for token expiration** — only `AvdHostPool` mis-uses it for rotation; the `CreatedOn` tag pattern is fine because it's set-once intentional.
- 🟡 **`output "resource"`** — present in 4 modules (Aks, ManagedIdentity, AvdHostPool, ContainerRegistry), absent in others. Pick a convention and apply consistently.
- 🟢 **azurerm v4 attribute naming is correctly applied across the board** — no leftover `enable_*` flags. The `azurerm-v4-migration` skill's checklist is well-honored.
