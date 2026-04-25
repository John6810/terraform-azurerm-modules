# Review A4 — Data, Storage, Crypto (8 modules)

Scope: `KeyVault`, `KeyVault-Key`, `KeyVault-Secrets`, `KeyVaultStack`, `Hsm`, `StorageAccount`, `DiagnosticSettings`, `FinOpsHub`. Provider: `azurerm ~> 4.0`. Cross-checked April 2026 against the official Terraform Registry docs.

---

## Module: KeyVault

**Purpose**: Standalone Azure Key Vault with RBAC, network ACLs, soft delete, purge protection, optional lock and role assignments. PE delegated to a separate module.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- Strong validation set on all naming variables (regex + length), 24-char KV name validator (gotcha #3 covered).
- Correct v4 field names: `rbac_authorization_enabled`, `purge_protection_enabled`, `public_network_access_enabled`, `soft_delete_retention_days`. No legacy `enable_rbac_authorization` or `enabled_for_*` deprecation issues.
- `prevent_destroy = true` lifecycle and a sane default (`purge_protection_enabled = true`, `public_network_access_enabled = false`, soft delete 90d, premium SKU).
- `role_assignments` map mirrors AVM pattern (id-or-name, principal_type, ABAC, delegated MI). Convenience deployer assignment is opt-in.
- `network_acls.bypass` validator matches Azure-allowed values (`AzureServices`/`None`).

**Issues**:
- Critical: none.
- Important (orange):
  - `bypass` is typed `string` but the upstream Azure schema accepts a single comma-joined string; semantics are fine for ALZ today but document so users don't pass `"AzureServices,None"`.
  - Output `uri` (not `vault_uri`) is a naming drift vs. the brief — most downstream consumers expect `vault_uri`. Minor consistency risk; recommend exposing both.
  - No output for `principal_id`/identity (KV has no MI here, fine), but no explicit `subscription_id` / `resource_group_name` outputs make cross-module wiring slightly more verbose.
  - The `tags` merge writes a `CreatedOn` tag every plan because `time_static` re-reads on `terraform refresh` only on first apply; current pattern is OK but `formatdate(... timeadd(... "1h"))` hardcodes a +1h offset that was likely meant for CET — comment is missing.
- Minor (yellow):
  - README example uses a v1.0.0 ref that doesn't yet exist in the repo (no tags created).
  - `assign_rbac_to_current_user = true` default is convenient but surprising in CI — flag in README.

**MS / Terraform docs cross-check**:
- `azurerm_key_vault` v4: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault — module already migrated (`rbac_authorization_enabled`, no deprecated `enabled_for_*`-style toggles missing).
- KV ACLs `bypass` only accepts `AzureServices` or `None` — confirmed.

**Recommended changes**:
1. Add output alias `vault_uri = azurerm_key_vault.this.vault_uri` to satisfy the conventional name.
2. Document the `+1h` `CreatedOn` offset (CET) inline.
3. Tag a `KeyVault/v1.0.0` to match README.

**Verdict**: ✅ OK

---

## Module: KeyVault-Key

**Purpose**: CMK / signing key materialization in an existing Key Vault, with optional rotation policy and default 2-year expiry.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- Map-based, validates `key_type`, `key_size`, `curve`, `key_vault_id` regex, and ISO datetime format on dates.
- Sensible default: `expiration_date = +2y` via `time_offset` — matches ALZ "Keys should have an expiration date" policy.
- Outputs both versioned and `versionless_id` — needed for KMS/CMK auto-rotation consumers (AKS KMS, disk encryption sets).

**Issues**:
- Important:
  - No `tags` ever applied to the keys: variable doc lists `tags` but the resource block does not set `tags = each.value.tags`. Silent drop.
  - Rotation policy: `azurerm_key_vault_key.rotation_policy` requires either `expire_after` or `automatic.time_before_expiry`. The schema validation should reject empty rotation policy objects (`{}`); add a validator.
  - No defaulting of `key_size` for RSA (validator requires it but no default = friction). Consider `optional(number, 2048)`.
- Minor:
  - No output `keys_versioned_ids` alias / per-attribute outputs are fine.
  - No standard naming (`subscription_acronym`/`environment`...) — keys are named explicitly per map entry, which is fine, but the module is the only one in the set that doesn't follow the standard-vars pattern. Document why.

**MS / Terraform docs cross-check**:
- `azurerm_key_vault_key` v4: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_key — `rotation_policy.automatic` requires exactly one of the two fields; module accepts both as optional, which can produce an apply-time error. Validate at variable level.

**Recommended changes**:
1. Wire `tags = each.value.tags` on the resource (silent bug today).
2. Add validator that `rotation_policy.automatic` has at least one of `time_after_creation`/`time_before_expiry` set.
3. Default `key_size` to 2048 for RSA when not provided.

**Verdict**: 🟡 Polish (one silent bug)

---

## Module: KeyVault-Secrets

**Purpose**: Push/generate secrets to a Key Vault with optional auto-generated random passwords and stable expiration via `time_offset`.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf.

**Strengths**:
- Mutual-exclusion validators on `value` vs. `generate`, and `expiration_date` vs. `expiration_days`.
- `lifecycle { ignore_changes = [value] }` enables out-of-band rotation without TF flip-flopping.
- `time_offset.expiration` keeps expiration dates stable across applies — clean.
- `versionless_ids` output suits VM CSE / AKS CSI consumers.

**Issues**:
- Important:
  - No README. Module behavior (notably the `ignore_changes = [value]` semantics — once created, TF will never reconcile a changed `value`) is subtle and needs to be documented.
  - `key_vault_id` validator misses the case-insensitive `Microsoft.KeyVault` casing variation (some pipelines lowercase the ID). Fine if all callers normalize; add `lower()` defensively.
  - Random generation runs `random_password` whose state holds the cleartext password — call this out (state must be encrypted, RBAC tightened on tfstate). Already handled by ALZ tfstate hardening, but the secret module should document it.
  - No content_type defaulting (e.g., `password` vs `connection-string`) — minor.
- Minor:
  - Output `secret_ids` is not marked sensitive — fine since they're versioned URIs, not values.
  - No `name` validator on KV secret name (max 127 chars, alphanumeric + dashes only). Add.

**MS / Terraform docs cross-check**:
- `azurerm_key_vault_secret`: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret — module aligns. Note `not_before_date` is supported by the resource but not exposed by the module (low impact).

**Recommended changes**:
1. Add a README documenting the `ignore_changes = [value]` lifecycle.
2. Add validation on secret `name` (max 127, regex `^[a-zA-Z0-9-]+$`).
3. Optionally surface `not_before_date`.

**Verdict**: 🟡 Polish

---

## Module: KeyVaultStack

**Purpose**: Composite RG + KV + PE wired together as direct resource blocks (per gotcha #2 — no nested `module {}` calls under Terragrunt source-copy).

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- Correctly implements gotcha #2 (direct resource blocks, no module composition).
- PE has `lifecycle { ignore_changes = [private_dns_zone_group] }` per gotcha #10.
- All standard naming vars validated; explicit overrides for `kv_suffix`/`kv_name`.
- Subnet ID regex validated.
- Outputs cover `key_vault_id`, `key_vault_name`, `key_vault_uri`, PE id, PE IP, and the connection status — strong wiring set.

**Issues**:
- Critical:
  - 🔴 KV name validation gap: the `kv_name` validator caps to 24 chars, but the **computed** `kv_name = "kv-${prefix}-${kv_suffix}"` has no length check. With `prefix = "{acr}-{env}-{region}"` (e.g. `api-prod-gwc` = 12) plus `kv-` (3) plus `-` (1) + `kv_suffix` ≤ 31 chars (per workload validator), the computed name can reach 47 chars and apply will fail server-side. Add `precondition` on the KV resource: `length(local.kv_name) <= 24`.
- Important:
  - PE `private_service_connection.is_manual_connection = false` is hardcoded — fine for ALZ but expose as variable for cross-tenant scenarios.
  - `assign_rbac_to_current_user = true` default — same caveat as KeyVault module.
  - No `tags` propagation to PE NIC (PE NICs don't support tags, but documenting this saves a question).
- Minor:
  - `kv_admin` role assignment uses string role name (lookup); fine but consumes a Graph call per plan.

**MS / Terraform docs cross-check**:
- `azurerm_private_endpoint`: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint — `ip_configuration.member_name = "default"` is correct for KV `vault` subresource.
- `azurerm_key_vault` PE subresource group ID is `vault` — correct.

**Recommended changes**:
1. Add a `precondition` block that fails plan when `length(local.kv_name) > 24`.
2. Expose `is_manual_connection` and `pe_request_message` as variables.
3. Tighten the workload regex to refuse names that would push past 24 chars.

**Verdict**: 🟠 Rework (length-bomb is a real footgun)

---

## Module: Hsm

**Purpose**: Managed HSM (Standard_B1) with optional inline RG, system UAMI, optional PE, soft delete + purge protection.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- Sensible v4 field names (`purge_protection_enabled`, `soft_delete_retention_days`, `public_network_access_enabled`).
- Auto-disables public access when a PE subnet is supplied (smart default).
- Defaults `admin_object_ids` to current deployer if empty — pragmatic for bootstrap.
- PE has `lifecycle { ignore_changes = [private_dns_zone_group] }`.

**Issues**:
- Critical:
  - 🔴 Module **provisions an HSM but never activates it**. Managed HSM requires a security domain download/activation step before keys can be created. There is no `azapi_resource` (`Microsoft.KeyVault/managedHSMs/securityDomain`) or doc note pointing to the manual step. New deployments will return 409 on any `azurerm_key_vault_managed_hardware_security_module_key` until activated. Add a README warning at minimum, ideally an `azapi` activation block.
  - 🔴 No HSM RBAC role assignments (data-plane). HSM uses a built-in role catalog (`Managed HSM Crypto User`, etc.) via `azurerm_key_vault_managed_hardware_security_module_role_assignment` — module has zero plumbing. Callers must wire this externally; not blocking but the module is incomplete.
- Important:
  - `network_acls` is hardcoded (`bypass = "AzureServices"` only); not configurable. KV ACL parity would help.
  - `sku_name = "Standard_B1"` is the only Standard tier in v4 today (good default), but accepts any string with no validator.
  - No `tags` validator and no purge_protection irreversibility note.
  - `identity_name` does not include `var.workload` so two HSMs in the same RG would collide on the UAMI name.
  - `name` has no length/regex validator (HSM name 3-24 alphanumeric, can include hyphens).
- Minor:
  - PE name `pep-${local.name}` — uses `local.name` not the standard PE naming `pep-{prefix}-hsm-{workload}`. Inconsistent with other modules.
  - `resource` output exposes the full HSM object — not marked sensitive (HSM doesn't expose secrets, OK).

**MS / Terraform docs cross-check**:
- `azurerm_key_vault_managed_hardware_security_module`: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_managed_hardware_security_module — supports `security_domain_*` arguments at create-time (key_vault_certificate IDs + quorum). Module ignores them; the activation is therefore manual or out-of-band. v4 also supports `network_acls.default_action`/`bypass`.

**Recommended changes**:
1. Add `security_domain_key_vault_certificate_ids`, `security_domain_quorum`, `security_domain_encrypted_data` as variables and pass them to the resource so activation is IaC-driven (or document the manual procedure prominently).
2. Add `name` and `sku_name` validators.
3. Make `network_acls` configurable (object var like KV/Storage).
4. Include workload in `identity_name` to avoid collisions.
5. Add HSM data-plane role assignment plumbing.

**Verdict**: 🟠 Rework

---

## Module: StorageAccount

**Purpose**: Generic Storage Account (StorageV2/Blob/BlockBlob/FileStorage) with containers, file shares, identity, blob retention, network rules, lock and RBAC.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- Strong defaults: TLS1_2, HTTPS-only, `allow_nested_items_to_be_public = false`, `shared_access_key_enabled = false`, `public_network_access_enabled = false`, ZRS replication, blob soft-delete 30d.
- Naming convention enforced (no hyphens, lowercase 3-24) — matches ACR-style exception.
- Full v4 surface: identity block, blob_properties dynamic, azure_files_authentication block, network_rules with bypass list.
- File shares + containers + RBAC + lock all in one module.

**Issues**:
- Important:
  - 🟠 Missing `cross_tenant_replication_enabled = false` (security default for v4 — Azure baseline policy expects this). Add as a variable defaulting to `false`.
  - 🟠 Missing `infrastructure_encryption_enabled` toggle (FedRAMP / CIS L2 control). Variable + default `false` is fine, but expose it.
  - 🟠 No `default_to_oauth_authentication` toggle (v4 supports it); recommended `true` when shared keys are disabled.
  - 🟠 No `sas_policy` or `key_vault_user_identity_id` for CMK — module doesn't expose `customer_managed_key`. CMK encryption is an ALZ requirement for production storage; should be a configurable nested block.
  - 🟠 `blob_properties` block: when `blob_delete_retention_days` is set, `versioning_enabled` and `change_feed_enabled` are not exposed — recommended for the tfstate-style hardening already mentioned in F-STOR-3.
  - 🟠 `sftp_enabled`/`is_hns_enabled` not exposed — needed for ADLS Gen2 use cases (FinOpsHub had to build its own SA for this reason).
  - 🟠 `network_rules.bypass` validator missing — should validate values ⊆ `["AzureServices","Logging","Metrics","None"]`.
- Minor:
  - `primary_access_key` output is sensitive but its existence with `shared_access_key_enabled = false` (default) returns empty — document.
  - File share validation: no regex on `name` or quota_gb bounds.

**MS / Terraform docs cross-check**:
- `azurerm_storage_account` v4: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account — many security-related arguments (above) are now first-class and recommended on by Microsoft Defender for Storage.

**Recommended changes**:
1. Add `cross_tenant_replication_enabled` (default `false`), `infrastructure_encryption_enabled`, `default_to_oauth_authentication`, `is_hns_enabled`, `sftp_enabled` variables.
2. Add `customer_managed_key` nested block + `identity_ids` for UAMI-based CMK wiring.
3. Add `versioning_enabled`/`change_feed_enabled` to `blob_properties`.
4. Add `bypass` validator on `network_rules`.
5. Document the F-STOR-2/F-STOR-3 by-design exceptions in README (flow logs LRS+shared key; tfstate shared key + public).

**Verdict**: 🟠 Rework — usable today but missing several v4 security controls Microsoft now expects.

---

## Module: DiagnosticSettings

**Purpose**: Reusable wrapper to create one or many `azurerm_monitor_diagnostic_setting` entries with LAW / Storage / Event Hub / partner sinks.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- Map-based (arbitrary key) — avoids unknown-key plan issues.
- Validators: target resource ID regex, "at least one destination" check.
- Uses v4 fields `enabled_log` and `enabled_metric` (not deprecated `log {}` / `metric {}` blocks). Correct migration.
- Pure pass-through, no naming opinions — appropriate for a generic wrapper.

**Issues**:
- Important:
  - 🟠 `enabled_log` block in v4 also supports a `category_group` argument (`AllLogs`, `Audit`). Module only takes `category`; many Azure resources only ship category groups (e.g. AKS) — limits applicability. Add `category_group` support.
  - 🟠 `log_analytics_destination_type` not exposed (controls dedicated/legacy table layout for AKS/etc.). Default `null` is fine, but you'll want it for AKS audit.
- Minor:
  - No outputs for `name` / per-key target (only `ids` and full resource map). Fine.
  - `marketplace_partner_resource_id` mapping uses `partner_solution_id` argument — verify the v4 schema name; v4 uses `partner_solution_id` (correct).

**MS / Terraform docs cross-check**:
- `azurerm_monitor_diagnostic_setting` v4: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting — `enabled_log` has both `category` and `category_group`; `log` and `metric` blocks were removed in v4.

**Recommended changes**:
1. Extend the `logs` input to accept either `string` (category) or `{ category_group = ... }`, or add a sibling `log_groups` list.
2. Expose `log_analytics_destination_type`.

**Verdict**: 🟡 Polish

---

## Module: FinOpsHub

**Purpose**: Microsoft FinOps Toolkit Hub deployment — RG, ADLS Gen2, ADX cluster + databases, ADF pipelines/triggers, Event Grid wiring, RBAC.

**Files inspected**: version.tf, variables.tf, main.tf, adf.tf, adx.tf, event_grid.tf, rbac.tf, output.tf, README.md, kql/*.

**Strengths**:
- Multi-file split (adf/adx/event_grid/rbac) is clean.
- Storage uses `is_hns_enabled = true` (ADLS Gen2 — required), `shared_access_key_enabled = false` (MI-only auth), TLS1_2, `allow_nested_items_to_be_public = false`. Good.
- ADX SystemAssigned identity + Storage Blob Data Contributor role wiring is correct for the parquet ingestion path.
- ADF MI is `Ingestor` on Ingestion DB and `Viewer` on Hub DB — least-privilege.
- KQL scripts re-applied via `force_an_update_when_value_changed = md5(file(...))` — deterministic re-runs.
- Lifecycle policy on `msexports/` and `ingestion/` containers — cost hygiene.
- ADX zones derived from SKU (`Dev` excluded) — sensible.

**Issues**:
- Critical:
  - 🔴 No FinOps Toolkit version pin documented. The hub `settings.json` writes `version = "0.12"` but the KQL scripts and pipeline JSON aren't versioned alongside. Microsoft's toolkit ships breaking schema changes between minor versions; a Renovate or git-tag pin is required. Add a top-of-module comment with the toolkit ref and document the upgrade procedure.
  - 🔴 ADF `pipelines/msexports_etl.json` is loaded via `file()` — if it references built-in functions or schema changes between toolkit releases, an `apply` can silently break exports. Hash the file (`md5(file(...))`) into a TF variable / output for auditability.
- Important:
  - 🟠 `azurerm_storage_account` here is hand-rolled instead of consuming the StorageAccount module (or vice versa). With the StorageAccount module gaps fixed (`is_hns_enabled` exposed), this could be a single source of truth.
  - 🟠 `enable_public_access` toggles **both** Storage and ADF public network — but EventGrid + the ADX EventGrid data connection will silently fail when public is disabled and no PE exists. Add validators or a "needs PE" precondition. README must call this out.
  - 🟠 ADF: `managed_virtual_network_enabled = false` — to keep traffic on the ALZ private path, this should be `true` and a managed VNet integration runtime configured. Hardcoded `false` bypasses the Palo perimeter.
  - 🟠 No PE for Storage / ADF / ADX / Event Hub. Module is intentionally network-flexible but the README must state that PE is the caller's responsibility.
  - 🟠 `azurerm_storage_account` — same security-toggle gaps as StorageAccount module: `cross_tenant_replication_enabled`, `infrastructure_encryption_enabled`, `default_to_oauth_authentication` not set.
  - 🟠 `cost_management_exports_principal_id` is null by default → exports won't be authorized. README should make this a "must-set" callout or fail-loud validator.
  - 🟠 ADX SKU defaults to `Dev(No SLA)_Standard_D11_v2` which is fine for dev but production users will forget to override. Add a validator that warns when env=`prod` and SKU starts with `Dev`.
  - 🟠 No outputs for ADF pipeline/trigger names or ADX database IDs — Power BI / consumers will need them.
  - 🟠 `time_static` import is required (var ref `time_static.time` in `local.common_tags`) but `version.tf` correctly declares `time` provider.
- Minor:
  - `evhns_name` (`evhns-{base}-finops`) — Event Hub Namespace names must be globally unique (6-50 alphanumeric + hyphens). Length is fine but no validator.
  - ADX databases use `P${days}D` ISO durations — correct.
  - `eventhub.message_retention = 1` (day) is the minimum; document.

**MS / Terraform docs cross-check**:
- Microsoft FinOps Toolkit: https://github.com/microsoft/finops-toolkit — current release 0.13; module pins 0.12 in `settings.json`. Behind by one minor.
- `azurerm_kusto_eventgrid_data_connection`: v4 supports `database_routing_type = "Multi"` for fan-out; module uses default (`Single`) — fine.
- `azurerm_data_factory.managed_virtual_network_enabled` requires recreation when changed — flag.

**Recommended changes**:
1. Pin toolkit version (`local.toolkit_version = "0.13"` or similar) and verify KQL/pipeline JSON match. Add Renovate config entry for the upstream repo.
2. Re-use the StorageAccount module (after StorageAccount fixes) instead of hand-rolling.
3. Make `managed_virtual_network_enabled` a variable defaulting to `true` for ALZ-perimeter compliance.
4. Add validators: env=prod ⇒ non-Dev ADX SKU, `cost_management_exports_principal_id` required when not in `nprd`.
5. Surface `cross_tenant_replication_enabled = false`, `infrastructure_encryption_enabled = true`, `default_to_oauth_authentication = true` on the storage account.
6. Add outputs for ADF pipeline name, trigger ID, database IDs (Hub and Ingestion), Event Hub ID.

**Verdict**: 🟠 Rework — works as a happy-path POC, but needs version pinning, network hardening, and richer validators before prod.

---

## Final verdict table

| Module             | Verdict        | Top concern |
|--------------------|----------------|-------------|
| KeyVault           | ✅ OK          | Output naming drift (`uri` vs `vault_uri`); README ref tag missing |
| KeyVault-Key       | 🟡 Polish      | Silent drop of `each.value.tags`; rotation_policy validator gap |
| KeyVault-Secrets   | 🟡 Polish      | No README documenting `ignore_changes = [value]` |
| KeyVaultStack      | 🟠 Rework      | Computed `kv_name` length not bounded — server-side fail at 24+ |
| Hsm                | 🟠 Rework      | No security-domain activation; no data-plane RBAC; UAMI name collision |
| StorageAccount     | 🟠 Rework      | Missing v4 security toggles (`cross_tenant_replication_enabled`, `infrastructure_encryption_enabled`, `default_to_oauth_authentication`, CMK) |
| DiagnosticSettings | 🟡 Polish      | Missing `category_group` and `log_analytics_destination_type` |
| FinOpsHub          | 🟠 Rework      | Toolkit version not pinned; ADF managed VNet disabled; storage hardening gaps |

**Cross-cutting recommendations**:
- Add a shared `tags` helper (tflib?) or convention for the `+1h CET CreatedOn` pattern — duplicated and undocumented.
- Tag module versions in git. README examples reference `v1.0.0` refs that don't exist.
- Storage hardening (cross_tenant, infra encryption, OAuth default, CMK) should land in StorageAccount first, then propagate to FinOpsHub by composition.
- KV-Stack and HSM both need length/precondition guards on computed names — pattern worth adding to all naming locals.
