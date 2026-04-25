# Review A5 — ALZ, Governance, Monitoring (12 modules)

**Reviewer**: Claude (Opus 4.7)
**Date**: 2026-04-25
**Scope**: 12 modules under `c:/Users/aerts/GitHub/terraform-azurerm-modules/`
**Provider baseline**: azurerm `~> 4.0`, terraform `>= 1.5.0`
**Cross-references**: Microsoft Learn (Azure Monitor / Defender / Grafana), Hashicorp Registry (azurerm v4 reference), Azure Verified Modules registry, Azure/Enterprise-Scale ALZ library, Azure/azure-monitor-baseline-alerts.

---

## Module: ActionGroup

**Purpose**: One-line wrapper for `azurerm_monitor_action_group` with email + Azure App push receivers.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- Clean naming pattern (`ag-{sub}-{env}-{region}-{workload}`), `time_static` + `computed_name`/`name` override pattern is correct and consistent with the ResourceGroup template.
- `email_addresses` and `push_email_addresses` marked `sensitive = true` — protects PII in plan output.
- `short_name` validation (`<= 12`) matches Azure API hard limit.

**Issues**:
- 🟡 Minor — `subscription_acronym`, `environment`, `region_code` are all `default = null` and only validated when non-null. If a caller forgets to wire root.hcl injection AND doesn't set `name`, you get the literal string `ag-----ama` with no error. Consider failing in `locals` when both `name` and the four naming components are null, or marking the four naming vars `nullable = false` once the injection contract is locked.
- 🟡 Minor — receiver `name` derived via `replace(email,"@","-at-")` will exceed 50 chars (Azure limit on `email_receiver.name`) for long mailboxes — add `substr(...,0,50)`.
- 🟡 Minor — only email + push receivers exposed. Webhook / EventHub / ITSM / SMS / VoiceCall are common ALZ AMBA targets; consider extending or documenting that this is intentional.
- 🟡 Minor — `tags` has `default = {}` but `CreatedOn` is computed once at apply and re-injected on every plan via `time_static` — this is OK, but `time_static` produces a new id only on first apply, which is the desired behaviour. Worth a comment so future maintainers don't replace it with `timestamp()`.

**Microsoft / azurerm v4 cross-check**:
- `azurerm_monitor_action_group` in azurerm v4.x — schema unchanged in v4 (no breaking change vs v3). `location` correctly hard-coded to `"global"`.
- AMBA (azure-monitor-baseline-alerts April 2026 release) increasingly defaults to common alert schema → confirmed `use_common_alert_schema = true`.

**Recommended changes**:
1. Add receiver-name `substr(...,0,50)` truncation.
2. Add SMS/Webhook receivers behind optional list inputs.
3. Document the null-naming failure mode in README.

**Verdict**: ✅ OK

---

## Module: AlzArchitecture

**Purpose**: Wraps `Azure/avm-ptn-alz/azurerm` to deploy MG hierarchy, sub placement, ALZ policy assignments (AMBA, DDoS, Defender, Backup).

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md (header only).

**Strengths**:
- AVM module pinned to exact `version = "0.13.0"` (not `~>`) — reproducible deployments. Same with `Azure/alz` provider `~> 0.19` and `azapi ~> 2.4`.
- `defender_plans` object supports the 12 individual MDFC plan toggles for `Deploy-MDFC-Config-H224` with validation restricting values to `DeployIfNotExists` / `Disabled`. Honest comment notes that `enableAscForApis` is not exposed by the policySet (correct — `Deploy-MDFC-Config_20240319` does not include APIs; it must be a separate assignment).
- `policy_default_values` carefully populates AMBA plumbing (UAMI BYO, action groups BYO, LAW id, private DNS sub).
- DDoS plan only injected at `mg-plat`, Backup only at `mg-idt` — scope-correct.

**Issues**:
- 🟠 Important — `Azure/avm-ptn-alz/azurerm` `0.13.0` (Apr 2026) is current at time of writing, but the ALZ library evolves quickly. There is no comment recording the pinned `library_references` (ALZ vs AMBA library refs). The AVM provider chooses the library by default — confirm/lock via `library_references` or document expected ALZ release `2025.10` or later.
- 🟠 Important — `architecture_name` defaults to `"prod"` but is also used as a suffix on `mg-lzr-${var.architecture_name}` etc. Per ALZ library default, the architecture is named `"alz"`. Verify the underlying YAML library you load actually contains MGs ending in `-prod` / `-nprd`; otherwise the `policy_assignments_to_modify` keys will not match anything and modifications will silently no-op. (This is a common ALZ AVM trap.)
- 🟠 Important — no validation that `subscription_placement` map keys match a real MG name in the architecture; mistake → AVM apply error. Consider documenting valid keys (`mgm`, `con`, `idt`, `sec`, `api`).
- 🟡 Minor — `email_security_contact = ""` default — Azure rejects empty string in some policy versions. Recommend `nullable = false` with a real default like `"security@<org>"` or fail if empty when MDFC plans are enabled.
- 🟡 Minor — `connectivity_subscription_id` is `nullable = false` but consumed only in `private_dns_zone_subscription_id` parameter — missing comment that this drives DINE PDNS placement.
- 🟡 Minor — outputs minimal: only `resource`, `management_group_ids`, `policy_assignment_identity_ids`. Missing `policy_role_assignments` / `policy_assignment_ids` exposed by the underlying module — useful when chaining `RbacAssignments` for custom DINE policies.

**Microsoft / AVM cross-check** (Apr 2026):
- AVM `Azure/avm-ptn-alz/azurerm`: latest stable `0.13.x` — see https://registry.terraform.io/modules/Azure/avm-ptn-alz/azurerm
- ALZ provider `azure/alz`: `~> 0.19` is current; provider releases ALZ library changes independently — pin both.
- `Deploy-AMBA-Notification` parameter `ALZAlertSeverity` confirmed against AMBA Apr 2026 release. PDNS / VM alerts have new defaults — consider updating `policy_default_values` to pass new AMBA params (`amba_alz_dns_zone_id`, `amba_alz_vmInsightsDcrId`).

**Recommended changes**:
1. Add a `library_references` variable so callers can override the ALZ/AMBA library version explicitly; document pinned versions in README.
2. Add `policy_assignment_ids` and `policy_role_assignment_ids` outputs.
3. Validate `email_security_contact` non-empty when any defender plan is `DeployIfNotExists`.
4. Document architecture-name → MG-name mapping contract.

**Verdict**: 🟡 Polish — production-ready, but version pinning + outputs need a polish pass.

---

## Module: AlzManagement

**Purpose**: Wraps `Azure/avm-ptn-alz-management/azurerm` for LAW + Automation Account + Sentinel + DCRs + AMA UAMI.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf.

**Strengths**:
- AVM source pinned `~> 0.9.0` and named UAMIs (`id-{sub}-{env}-{region}-law` / `-ama`).
- LAW SKU auto-selected (`CapacityReservation` if > 100 GB/day else `PerGB2018`) with conditional `reservation_capacity`.
- `local_authentication_enabled = false` (LAW), `automation_account_local_authentication_enabled = false` — Azure AD only — best practice.
- Three DCRs created (change tracking, VM insights, Defender SQL) with naming convention.
- `create_resource_group` / `resource_group_name` toggle is clean.

**Issues**:
- 🟠 Important — AVM module pinned `~> 0.9.0` allows minor upgrades — fine for now but lock to exact when promoting to prod (`0.9.x` may introduce breaking schema additions).
- 🟠 Important — LAW UAMI created **outside** the AVM module (`azurerm_user_assigned_identity.law`), then injected into `automation_account_identity.identity_ids`. Order of operations is fine, but on `terraform destroy` the UAMI may try to delete before the AA is untied → cyclic. Add explicit `depends_on` or move identity inside the AVM module if it supports it.
- 🟠 Important — Sentinel onboarding only sets `customer_managed_key_enabled` — Sentinel solutions / data connectors are NOT managed here. Document that this module just *enables* Sentinel and downstream connectors are out of scope.
- 🟡 Minor — `workload` default `"01"` produces names like `law-mgm-prod-gwc-01` — the rest of the codebase uses workload words (`management`, `network`). Consider default `"management"` for consistency.
- 🟡 Minor — no validation on `log_retention_days` upper bound (Azure max 730 / 4383 with archive).
- 🟡 Minor — `enable_cmk = false` default but no actual CMK key id input — flag is forwarded to `cmk_for_query_forced` and `sentinel_onboarding.customer_managed_key_enabled` but the Key Vault key wiring is the AVM's job — document that the caller still needs to grant the LAW MI access.
- 🟡 Minor — `output "resource"` is `sensitive = true` — fine for safety, but it makes downstream `module.alz_management.resource.something` opaque to dependents. Expose specific outputs you need (already mostly done).

**Microsoft / AVM cross-check**:
- `Azure/avm-ptn-alz-management/azurerm` 0.9.x — see https://registry.terraform.io/modules/Azure/avm-ptn-alz-management/azurerm. April 2026 still aligned with ALZ Reference Implementation.
- `OMSGallery/*` solutions are deprecated per Microsoft (transitioning to native Insights), but still required for ALZ baseline compatibility. Note in README that this is transitional.

**Recommended changes**:
1. Pin AVM to exact `0.9.x` patch.
2. Default `workload` to `"management"` to match codebase.
3. Add `depends_on = [module.alz_management]` on the UAMI or restructure for clean destroy.
4. Document Sentinel scope boundary.

**Verdict**: ✅ OK — solid wrapper, polish for prod.

---

## Module: ResourceGroup

**Purpose**: Resource Group with optional management lock and bulk role assignments.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- Reference template for the codebase: `time_static` → `computed_name`/`name` → resource. All other modules follow this pattern.
- `name` regex matches Azure RG name rules (1-90, no period at end).
- `lock` object with regex-validated `kind` and optional `name`.
- `role_assignments` map with rich shape (`condition`, `condition_version`, `principal_type`, `delegated_managed_identity_resource_id`, `skip_service_principal_aad_check`).
- Smart `role_definition_id_or_name` dispatch via `strcontains` on the well-known substring.

**Issues**:
- 🟠 Important — ResourceGroup module has its own `lock` block AND a separate `ResourceLock` module exists. This duality means the same RG can be locked twice (by name collision → apply error). Pick one source of truth, or document: *"Use `lock` here for single-RG simple cases; use `ResourceLock` for multi-resource bulk locks."*
- 🟠 Important — `lock` validation block uses `kind` value but the resource block sets `lock_level = var.lock.kind`. The default lock `notes` text doesn't mention `ReadOnly` semantics fully ("Cannot delete or modify"). Fine, but ergonomics: consider building the notes from a `coalesce(var.lock.notes, default_per_kind)`.
- 🟡 Minor — no `lifecycle { prevent_destroy = true }` on the RG. RGs are usually critical and cascade-delete-everything. Default to `false` is fine for module ergonomics but document the risk.
- 🟡 Minor — outputs lack `principal_type` map / role assignment ids — add `output "role_assignment_ids"`.
- 🟡 Minor — `workload` validation `1 to 31 chars` but pattern is `^[a-z][a-z0-9_-]{1,30}$` — minimum is 2 chars (anchor + 1). Fix the error message or the regex `{0,30}`.

**azurerm v4 cross-check**:
- `azurerm_resource_group` unchanged in v4. `principal_type` is a stable field.
- `azurerm_management_lock` unchanged. `azurerm_role_assignment` `condition`/`condition_version`/`principal_type` all stable in v4. PIM-friendly: `condition` supports ABAC for storage etc.

**Recommended changes**:
1. Document the ResourceGroup-lock vs ResourceLock-module duality.
2. Fix workload regex `{1,30}` → `{0,30}` or update error to "2 to 31".
3. Add `role_assignment_ids` output.

**Verdict**: ✅ OK — battle-tested template, light polish.

---

## Module: ResourceLock

**Purpose**: Bulk management locks via `for_each`, with `enable_locks` kill switch for `terraform destroy`.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- `enable_locks = false` master switch — directly addresses CLAUDE.md gotcha #11 (locks block `terraform destroy`).
- `notes` default localised to "Lock applied by Terragrunt — Azure Landing Zone".
- Map shape with optional defaults — clean ergonomics.
- Validation for `lock_level` and scope regex.

**Issues**:
- 🟠 Important — the `for_each = var.enable_locks ? var.locks : {}` pattern means flipping `enable_locks` from `true` to `false` will *destroy* all locks in state on the next apply, not just skip them. That is the intended semantic for "let me destroy", but it's risky if someone toggles it temporarily. Consider:
  - Using `lifecycle { ignore_changes = all }` or
  - Documenting a 2-step procedure (`enable_locks=false; tg apply; tg destroy; tg apply` to restore).
  Currently the README needs to be very explicit.
- 🟠 Important — scope validation regex only accepts RG-scoped or child-of-RG resources. Subscription-scope locks (`/subscriptions/<id>` only) would fail validation. If you ever need sub-level locks, this rejects them. Either widen regex or rename module to `ResourceGroupLock`.
- 🟡 Minor — `name` default `"lock-CanNotDelete"` — if multiple locks with default name target the same scope, Azure will reject. Make the default key-derived: `coalesce(name, "lock-${each.key}")`.
- 🟡 Minor — no input/output validation that `name` length ≤ 90.
- 🟡 Minor — output `resources` exposes the entire object map — not sensitive but verbose.

**azurerm v4 cross-check**:
- `azurerm_management_lock` schema unchanged in v4 (`lock_level`, `name`, `notes`, `scope`).

**Recommended changes**:
1. Default `name` to key-derived (`lock-${each.key}`).
2. Widen `scope` regex to include subscription scope, or rename module.
3. README: explicit warning on `enable_locks=false` semantics.

**Verdict**: ✅ OK

---

## Module: RbacAssignments

**Purpose**: Bulk RBAC for Entra groups (resolved by display_name) and identities/SPs (by `principal_id`), via two map inputs.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- Two clean variables: `group_assignments` (resolves by display name via `data.azuread_group`) and `identity_assignments` (direct principal_id, supports `principal_type`).
- `principal_type` validated against full enum (`User`, `Group`, `ServicePrincipal`, `ForeignGroup`, `Device`).
- `condition` / `condition_version` exposed → ABAC-ready (e.g. Storage Blob ABAC, AKS Kubelet conditions).
- De-duplication of group lookups via `toset(...)`.
- Smart role-id-or-name dispatch.

**Issues**:
- 🔴 Critical — `data.azuread_group` will fail at plan time if the group doesn't exist or the SP running the plan can't read it. For F-POL-F1 cleanup of 38 custom roles, callers passing identity-based assignments will be unaffected, but this needs to be documented in README. Suggest adding `security_enabled = true` filter and an optional fallback to `mail_nickname`.
- 🟠 Important — group resource block is missing `principal_type = "Group"` — Azure recently rejects role-assignment creates on Entra groups when `principal_type` is omitted with `UnmatchedPrincipalType` (CLAUDE.md status note: `da4e610 rbac-avd: set principal_type=Group on the 3 assignments` — same issue!). Add `principal_type = "Group"` to `azurerm_role_assignment.groups`.
- 🟠 Important — no `skip_service_principal_aad_check` on the groups block (unused for groups but inconsistent with identities block).
- 🟡 Minor — both resource types use the same `for_each` namespace; if a key clashes between `group_assignments` and `identity_assignments`, both succeed but apply order is non-deterministic. Add a validation that the key sets don't overlap (or fold into one map with discriminator).
- 🟡 Minor — output `group_resources` / `identity_resources` are not sensitive; principal IDs are not secrets but `condition` strings might leak structure.

**azurerm v4 cross-check**:
- `azurerm_role_assignment.principal_type` was added in azurerm v3.x; in v4.x it's the canonical way to dodge `UnmatchedPrincipalType`. Documented at https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment#principal_type-1
- `azuread_group` data source `~> 3.0` — current.

**Recommended changes**:
1. **Add `principal_type = "Group"` on `azurerm_role_assignment.groups`** — directly aligns with the recent `da4e610` lesson.
2. Validate that `group_assignments` and `identity_assignments` keysets don't overlap.
3. Document that the running SP needs `Directory.Read.All` (or `Group.Read.All`) for `data.azuread_group`.

**Verdict**: 🟠 Rework (small) — the missing `principal_type=Group` is a known footgun in this exact codebase.

---

## Module: PolicyExemption

**Purpose**: Policy exemptions dispatched to RG / Subscription / Management Group scopes via per-entry scope key.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf.

**Strengths**:
- Three-scope dispatch via three `azurerm_*_policy_exemption` resources, gated on which scope id is non-null.
- `validation` enforces *exactly one* scope id per exemption — strong guard against silent miswire.
- Scope-id regex on `resource_group_id` and `management_group_id` — catches typos at plan time.
- `exemption_category` validated `Waiver` / `Mitigated`.
- `metadata` JSON-encoded (Azure expects a JSON object).
- Clean merged outputs across the three resource types.

**Issues**:
- 🟠 Important — no validation that `subscription_id` is a GUID or full sub path. Add `can(regex("^([0-9a-fA-F-]{36}|/subscriptions/[^/]+)$", e.subscription_id))`.
- 🟠 Important — `description` is optional but module docs say "MANDATORY for audit trail" — promote `description` to required (`optional(string)` → `string`) or add a validation block.
- 🟡 Minor — `expires_on` not validated as RFC3339 — Azure will reject malformed strings, but plan-time validation is cheaper.
- 🟡 Minor — `policy_definition_reference_ids` — when targeting an initiative, the IDs must exist in that initiative; no way to validate this in TF, but a clear comment in description would help.
- 🟡 Minor — no output `resources` exposing the full objects (only `ids` and `names` merged) — fine for security but consider adding sensitive resource map for debugging.

**azurerm v4 cross-check**:
- `azurerm_resource_group_policy_exemption`, `azurerm_subscription_policy_exemption`, `azurerm_management_group_policy_exemption` — all stable in v4. See https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group_policy_exemption
- The recent breaking change (per CLAUDE.md context) — `resource_group_id` moved from top-level into per-exemption map AND new `subscription_id` / `management_group_id` scopes — is correctly modelled. ✅

**Recommended changes**:
1. Promote `description` to required.
2. Add validation on `subscription_id` and `expires_on`.
3. Document in README the migration path from the old top-level `resource_group_id` shape.

**Verdict**: ✅ OK — well-structured for the recent 3-scope refactor.

---

## Module: Naming

**Purpose**: Wraps `Azure/naming/azurerm` and adds Palo Alto / custom resource naming.

**Files inspected**: version.tf, variables.tf, main.tf, outputs.tf, README.md, QUICK_REFERENCE.md.

**Strengths**:
- Two-track naming: official AVM `Azure/naming/azurerm` for standard resources + custom local for Palo Alto / NSG rules / route table routes / VM / NIC / disk / pip.
- Validation on `prefix`/`suffix` length (≤10) and charset.
- `unique_length` validated `1..8`.
- Pre-built `built_names` map with `name_suffixes` (e.g. `["trust","untrust","mgmt"]`) — useful for Palo Alto multi-NIC.
- Sanitization for storage (24 chars, lowercase, alphanumeric only) — addresses CLAUDE.md gotcha #3.

**Issues**:
- 🟠 Important — gotcha #8 in CLAUDE.md: *"Palo Alto custom roles — name must include `${local.prefix}-${var.workload}` to avoid env conflicts"*. The `custom_names` builder uses `prefix-shortname-env-region-suffix` but does NOT include workload. If two Palo deployments in different workloads share the same env+region, the custom-role names will collide. Add `workload` (or accept it as input here) into the custom-name template.
- 🟠 Important — `Azure/naming/azurerm` pinned `~> 0.4.3` (Apr 2026: 0.4.x line). The naming module has had breaking changes; pin exact `0.4.3`.
- 🟠 Important — `environment` validation enum is `["dev", "test", "nprd", "prod", "dr", "sandbox", "lab"]` but other modules in this review use the regex `^[a-z]{2,4}$` — this means callers passing `nprd` are OK but `staging` (5 chars) breaks here yet passes others. Decide and document.
- 🟡 Minor — `region` validation `^[a-z]{2,5}$` matches `gwc`, `weu`, but the AVM naming module historically expects `germanywestcentral` long form for some resource types — verify.
- 🟡 Minor — `outputs.tf` filename plural; rest of codebase uses `output.tf` (singular). Cosmetic but inconsistent.
- 🟡 Minor — no `subscription_acronym` standard variable — naming module is stand-alone, but downstream usage requires the caller to inject sub acronym manually. Consider an optional input.

**Recommended changes**:
1. **Add `workload` input and include in custom_names template** to fix gotcha #8 collisions.
2. Rename `outputs.tf` → `output.tf`.
3. Decide on `environment` set vs regex — propagate convention.
4. Pin `Azure/naming/azurerm` to exact patch.

**Verdict**: 🟠 Rework — the missing `workload` in custom names is the documented Palo Alto footgun.

---

## Module: Grafana

**Purpose**: Azure Managed Grafana with UAMI, Azure Monitor Workspace integration, and Grafana RBAC for Entra groups.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- Creates RG + UAMI + Grafana + integrations + RBAC in a single deploy.
- Three Grafana RBAC roles exposed (`Admin`, `Editor`, `Viewer`).
- `api_key_enabled = false` default — aligns with Microsoft deprecation guidance (use MI / Entra).
- `azure_monitor_workspace_integrations` dynamic block — properly drives Prometheus AMW links.
- `public_network_access_enabled = false` default — good ALZ posture.

**Issues**:
- 🟠 Important — `zone_redundancy_enabled` is **immutable** post-deploy (Azure API rebuilds the instance). For prod (`true` default) this is fine, but if a caller toggles it, Terraform will issue a *destroy+create* with no warning. Add `lifecycle { ignore_changes = [zone_redundancy_enabled] }` OR document explicitly. Mentioned in CLAUDE.md task list — confirmed not yet implemented.
- 🟠 Important — no `lifecycle { prevent_destroy = true }` on the Grafana resource; for prod observability you usually want this.
- 🟠 Important — `grafana_admin/editor/viewer_group_object_ids` are bare `list(string)` of object IDs. If a group is deleted in Entra, the role assignment becomes orphaned and Terraform plan stays in drift. No `principal_type = "Group"` set → can hit `UnmatchedPrincipalType` (same as RbacAssignments). **Add `principal_type = "Group"`**.
- 🟠 Important — `identity_role_assignments` lacks `principal_type` plumbing — same issue.
- 🟡 Minor — naming uses `grafana_name = "amg-${local.base}-01"` — the `-01` is hardcoded; if you ever need 2 instances, breaks.
- 🟡 Minor — no validation on `grafana_major_version` (currently `"11"`); Microsoft now supports `10`/`11` (Apr 2026 — `12` GA upcoming).
- 🟡 Minor — RG created inline (`azurerm_resource_group.this`) — inconsistent with AlzManagement which has a toggle. Consider a `create_resource_group` flag.

**Microsoft cross-check**:
- `azurerm_dashboard_grafana` schema in azurerm v4 — `api_key_enabled` is still supported but Microsoft documents Managed Identity / Entra as preferred. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/dashboard_grafana
- Grafana 11 is current; 12 GA expected H1 2026.

**Recommended changes**:
1. **Add `principal_type = "Group"`** on the three Grafana RBAC blocks + on `identity` block.
2. Add `lifecycle { ignore_changes = [zone_redundancy_enabled] }`.
3. Add `lifecycle { prevent_destroy = true }` on the Grafana instance for prod.
4. Make instance suffix configurable.

**Verdict**: 🟠 Rework — `principal_type` + ZR immutability handling are required before prod.

---

## Module: LogAnalyticsAlerts

**Purpose**: KQL alerts via `azurerm_monitor_scheduled_query_rules_alert_v2`, plus an optional DCE+DCR+custom-table ingestion pipeline (Logs Ingestion API / OAuth).

**Files inspected**: version.tf, variables.tf, main.tf, output.tf.

**Strengths**:
- Uses `_v2` resource (correct — the legacy `azurerm_monitor_scheduled_query_rules_alert` is deprecated).
- Excellent documentation in `variables.tf` — schema discussion of `TimeGenerated` typing bug is accurate and rare to find in modules.
- DCR-based ingestion pipeline replaces the deprecated HTTP Data Collector API (Microsoft retiring 2026-09-14).
- `azapi_resource` for custom tables to side-step the azurerm `_CL` table limitations and to inject `TimeGenerated dateTime` first column (correct camelCase per ColumnTypeEnum).
- DCR `transformKql` default normalises `TimeGenerated` via `iff(isnull(...))` — `coalesce()` is correctly noted as unsupported in DCR transform.
- `Monitoring Metrics Publisher` role assignment for ingestion principals at DCR scope — minimum-privilege correct.
- Clean dependency: `depends_on = [azapi_resource.custom_table, azurerm_monitor_data_collection_rule.this]` on alerts.

**Issues**:
- 🟠 Important — `azapi` is required for `custom_tables` but the version pin `~> 2.0` is one major behind `Azure/azapi 2.4` used in AlzArchitecture/AlzManagement. Bump to `~> 2.4` for consistency and to inherit the same provider instance.
- 🟠 Important — no validation on `severity` (must be 0..4); fix with `validation { condition = severity >= 0 && severity <= 4 }`.
- 🟠 Important — `failing_periods` allows mismatch (`minimum_failing_periods_to_trigger_alert > number_of_evaluation_periods` would be rejected by Azure). Add a validation.
- 🟠 Important — `custom_tables` retention not validated (1..730 / 1..4383).
- 🟡 Minor — alert `name = "${name_prefix}-${each.key}"` — `name_prefix` = `alert-{acr}-{env}-{region}` so you get `alert-mgm-prod-gwc-...`. The standard would be `sqra-` or `kqla-` to follow Azure abbreviation conventions, but `alert-` is readable.
- 🟡 Minor — DCE `kind = "Linux"` is hardcoded — almost always correct for Logs Ingestion (no Windows variant), but worth a comment.
- 🟡 Minor — `data_collection_rule_immutable_id` output is precisely the right thing to expose for clients building Logs Ingestion API URLs. ✅
- 🟡 Minor — no `tags` merge with `CreatedOn` — inconsistent with other modules.

**Microsoft cross-check**:
- `azurerm_monitor_scheduled_query_rules_alert_v2` is current; the v1 resource (`azurerm_monitor_scheduled_query_rules_alert`) is deprecated since 2024 — confirmed not used.
- Logs Ingestion API + DCR-based custom logs is the only supported path post-2026-09-14 (Data Collector API retirement). https://learn.microsoft.com/azure/azure-monitor/logs/logs-ingestion-api-overview
- `Microsoft.OperationalInsights/workspaces/tables@2022-10-01` — confirmed correct API version.

**Recommended changes**:
1. Bump `azapi` to `~> 2.4`.
2. Add validations on `severity`, `failing_periods` consistency, retention upper bounds.
3. Add `CreatedOn` tag merge for parity with other modules.

**Verdict**: ✅ OK — one of the strongest modules in the set; v2 resource + DCR ingestion + TimeGenerated handling is genuinely good engineering.

---

## Module: PrometheusAlertRules

**Purpose**: Prometheus alert rule groups attached to AKS + Azure Monitor Workspace.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf.

**Strengths**:
- `azurerm_monitor_alert_prometheus_rule_group` with both AMW and AKS in `scopes` — correct for AMBA-style alerts.
- `for_each` over `rule_groups` map — clean multi-group support.
- `cluster_name` set so Prometheus can resolve rule scope.
- `alert_resolution { auto_resolved = true, time_to_resolve = "PT15M" }` — matches Microsoft default behaviour.
- Validation on `aks_cluster_id` and `monitor_workspace_id` regexes — catches misuse early.

**Issues**:
- 🟠 Important — Azure imposes a hard limit of **20 rules per group** (mentioned in description but NOT validated). Add `validation { condition = alltrue([for g in var.rule_groups : length(g.alerts) <= 20]) ... }`.
- 🟠 Important — `action_group_id` is a single string — Microsoft supports up to 5 action groups per Prometheus rule. Consider `list(string)` with `length <= 5` validation, then `dynamic "action"`.
- 🟡 Minor — `alert_resolution` is hard-coded `auto_resolved = true, PT15M`. Make it overridable per rule (some criticals should NOT auto-resolve).
- 🟡 Minor — no validation on `severity` (0..4) or ISO8601 strings.
- 🟡 Minor — `tags` merged with `CreatedOn` ✅ — consistent.
- 🟡 Minor — outputs only `ids`/`names`; `resources` map could be useful for downstream chaining.

**Microsoft cross-check**:
- `azurerm_monitor_alert_prometheus_rule_group` is current azurerm v4 stable. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_alert_prometheus_rule_group
- AMBA Prometheus rules library https://github.com/Azure/azure-monitor-baseline-alerts has both alert and recording rules — confirm caller is sourcing rule expressions from there, not freehand.

**Recommended changes**:
1. **Add hard validation `length(alerts) <= 20` per group**.
2. Allow multiple `action_group_ids`.
3. Make `alert_resolution` overridable per rule.

**Verdict**: 🟡 Polish

---

## Module: PrometheusCollector

**Purpose**: DCR + DCE + DCR associations to forward AKS Prometheus metrics to an Azure Monitor Workspace, with optional recommended recording rules.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, recording_rules.tf, README.md.

**Strengths**:
- Three required pieces: DCR (`prometheus_forwarder` data source), DCRA for AKS (the actual association), and the **special-named DCE association `configurationAccessEndpoint`** — correctly noted in comment ("Name MUST be `configurationAccessEndpoint`"). This is a documented Azure quirk that's easy to miss.
- Recommended Node + Kubernetes recording rules, sourced from `Azure-Samples/aks-managed-prometheus-and-grafana-bicep` — correct PromQL expressions, properly attributed.
- `enable_recording_rules` toggle — opt-out friendly.
- DCR `kind = "Linux"`, `streams = ["Microsoft-PrometheusMetrics"]` — correct for managed Prometheus.

**Issues**:
- 🟠 Important — `azurerm_monitor_data_collection_rule_association.dce` uses `data_collection_endpoint_id` as a top-level resource argument; in azurerm v4 this association resource has the parameter, but verify against current azurerm v4.x docs — there were schema tweaks. Confirmed valid in 4.x. ✅
- 🟠 Important — recording rules have **no `action`** (correct — recording rules don't fire alerts) and **no `for`** (also correct — recording rules emit on every interval). But they share the same `azurerm_monitor_alert_prometheus_rule_group` resource as alerts; ensure the resource accepts `record` without `alert`. azurerm 4.x supports both → ✅ but worth a comment.
- 🟠 Important — recording rule groups are named `NodeRecordingRulesRuleGroup-${cluster_name}` and `KubernetesRecordingRulesRuleGroup-${cluster_name}` — fine, but if `var.aks_cluster_name` is long or non-DNS-compliant, the resulting name may exceed Azure limits (260 chars — unlikely but).
- 🟠 Important — recommended rules hard-code `interval = "PT1M"`. Microsoft's default for these recording rules is `PT1M` → correct, but expose as variable for tuning.
- 🟡 Minor — DCRA `name` for prometheus is `dcra-${prefix}-${workload}` but the DCE association is the magic literal `configurationAccessEndpoint` — naming is asymmetric (intentional, but document).
- 🟡 Minor — outputs only expose DCR; expose DCRA ids too for downstream chaining.

**Microsoft cross-check**:
- DCE/DCRA/`prometheus_forwarder` schema for Managed Prometheus on AKS — confirmed against https://learn.microsoft.com/azure/azure-monitor/containers/prometheus-metrics-enable.
- The recording rules match the Microsoft-provided baseline (`AKS Managed Prometheus Recording Rules`). Note that AMBA also publishes a more comprehensive set — consider migrating to the AMBA-published list for ALZ alignment. https://github.com/Azure/azure-monitor-baseline-alerts/tree/main/services/Microsoft.ContainerService

**Recommended changes**:
1. Expose `recording_rules_interval` as a variable.
2. Output DCRA ids.
3. Consider migrating recording rules to AMBA library version.

**Verdict**: ✅ OK — good wrapper for a notoriously fiddly piece of plumbing.

---

# Final Verdict Table

| # | Module | Verdict | Top issue |
|---|--------|---------|-----------|
| 1 | ActionGroup | ✅ OK | Receiver name 50-char truncation |
| 2 | AlzArchitecture | 🟡 Polish | AVM/library version pinning + missing outputs |
| 3 | AlzManagement | ✅ OK | UAMI / AVM destroy ordering |
| 4 | ResourceGroup | ✅ OK | Lock duality with `ResourceLock` module |
| 5 | ResourceLock | ✅ OK | Subscription-scope rejected by validation |
| 6 | RbacAssignments | 🟠 Rework | **Missing `principal_type = "Group"`** (recently fixed in `da4e610`) |
| 7 | PolicyExemption | ✅ OK | `description` should be required |
| 8 | Naming | 🟠 Rework | **Custom names lack `workload`** → Palo Alto cross-env collision (gotcha #8) |
| 9 | Grafana | 🟠 Rework | **Missing `principal_type = "Group"`** + ZR immutability lifecycle |
| 10 | LogAnalyticsAlerts | ✅ OK | `azapi ~> 2.0` should match `~> 2.4` elsewhere |
| 11 | PrometheusAlertRules | 🟡 Polish | No `<= 20 rules` validation; single `action_group_id` |
| 12 | PrometheusCollector | ✅ OK | Recording rules `interval` hardcoded |

## Cross-cutting observations

1. **`principal_type = "Group"` consistency** — RbacAssignments (groups block) and Grafana (admin/editor/viewer) are both at risk of `UnmatchedPrincipalType`. The recent `da4e610 rbac-avd: set principal_type=Group on the 3 assignments` commit shows this was already hit in the AVD module — fix once at the module level.
2. **AVM version pinning** — `Azure/avm-ptn-alz/azurerm` is pinned exact (`0.13.0`); `Azure/avm-ptn-alz-management/azurerm` is `~> 0.9.0` (loose); `Azure/naming/azurerm` is `~> 0.4.3`. Standardise on **exact pins** for ALZ-critical modules and document the upgrade procedure.
3. **`azapi` version drift** — `~> 2.4` in AlzArchitecture/AlzManagement vs `~> 2.0` in LogAnalyticsAlerts. Pick one (`~> 2.4`) repo-wide.
4. **`workload` in custom names (gotcha #8)** — Naming module needs the workload input to avoid Palo Alto custom-role name collisions across environments.
5. **`CreatedOn` tag pattern** — present in ActionGroup / ResourceGroup / Grafana / Prometheus but missing in LogAnalyticsAlerts and the AVM-wrapping modules. Consider a shared helper or just document.
6. **F-POL-F1 cleanup of 38 custom roles** — `RbacAssignments.identity_assignments` is the right tool for bulk cleanup; once `principal_type = "Group"` is fixed in the groups block, the module is fully suitable.
7. **AMBA April 2026 release** — newer parameters (`amba_alz_dns_zone_id`, `amba_alz_vmInsightsDcrId`) not yet plumbed through `AlzArchitecture.policy_default_values` — minor gap.
8. **Locks vs `terraform destroy`** — `ResourceLock.enable_locks` toggle is good; ResourceGroup module's inline `lock` does not have a similar kill switch. Either add one or document migrating critical RG locks to ResourceLock.

## Priority queue (do in this order)

1. **🔴 RbacAssignments**: add `principal_type = "Group"` on the groups block.
2. **🔴 Grafana**: add `principal_type = "Group"` on three RBAC blocks + on `identity_role_assignments` if any of them are groups.
3. **🟠 Naming**: add `workload` input + include in custom_names template (fixes gotcha #8).
4. **🟠 Grafana**: `lifecycle { ignore_changes = [zone_redundancy_enabled] }`.
5. **🟠 PrometheusAlertRules**: validate `length(alerts) <= 20`; allow multi action group.
6. **🟠 LogAnalyticsAlerts**: bump `azapi` to `~> 2.4` for repo-wide consistency.
7. **🟡 AlzArchitecture/AlzManagement**: pin AVM modules to exact patches; document library_references.
8. **🟡 PolicyExemption**: promote `description` to required.
9. **🟡 ResourceLock**: default `name` to `lock-${each.key}`.
10. **🟡 Naming**: rename `outputs.tf` → `output.tf` (consistency).

---

**End of review.**
