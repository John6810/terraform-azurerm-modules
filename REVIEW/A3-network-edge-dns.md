# Review A3 — Network Edge & DNS (9 modules)

Date: 2026-04-25
Reviewer: Code review pass on `Network Edge / DNS / PE` modules
Provider: `azurerm ~> 4.0`, Terraform `>= 1.5.0`
Scope: `PrivateEndpoint`, `PrivateDnsZones`, `PrivateDnsZonesCorp`, `DnsResolver`, `FlowLogs`, `NetworkWatcher`, `DdosProtection`, `Ampls`, `AzureMonitorWorkspace`

---

## Module: PrivateEndpoint

**Purpose**: Generic many-to-one Private Endpoint factory (map-driven), DNS zone group + ALZ DINE-friendly lifecycle.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- `map(object)` shape with rich validations: subnet_id regex, resource_id regex, IPv4 regex, manual-connection consistency check, non-empty subresource_names.
- Implements gotcha #10 correctly: `lifecycle { ignore_changes = [private_dns_zone_group] }` for ALZ DINE coexistence.
- Supports static IP allocation via `ip_configuration` (azurerm v4 nested block) and `custom_network_interface_name`.
- Granular outputs: `resources`, `ids`, `private_ip_addresses`.

**Issues**:
- 🟠 Important: `data.azurerm_private_endpoint_connection.this` is dead weight — never referenced in outputs, just adds an extra read at every apply.
- 🟠 Important: The `private_ip_addresses` output reads from `private_service_connection[0].private_ip_address`, which is empty in azurerm v4 unless the underlying API returns it. Prefer `network_interface[0].private_ip_address` (always populated) — see [`azurerm_private_endpoint`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint#attributes-reference).
- 🟡 Minor: missing standard naming vars (`subscription_acronym`, etc.) — module is intentionally name-driven by caller, OK but document explicitly.
- 🟡 Minor: README example shows `private_ip_address` without a matching `subresource_names` warning — single-NIC PEs fail if the chosen subresource doesn't accept static IP.

**Microsoft / Terraform official-docs cross-check (April 2026)**:
- v4 supports `ip_configuration.subresource_name` and `member_name` (used). ✅
- `private_dns_zone_group` block fully managed by ALZ DINE policy `Deploy-Private-DNS-*` — `ignore_changes` is the correct pattern.
- No azapi needed.

**Recommended changes** (priority-ordered):
1. Drop the `data.azurerm_private_endpoint_connection` block, or actually wire it to an output.
2. Switch `private_ip_addresses` output to `v.network_interface[0].private_ip_address`.
3. Add a brief lifecycle note in README pointing at gotcha #10.

**Verdict**: ✅ OK (light polish)

---

## Module: PrivateDnsZones

**Purpose**: Dedicated RG + AVM-backed deployment of all ALZ `privatelink.*` zones with VNet links.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- Delegates the boilerplate zone list to AVM `Azure/avm-ptn-network-private-link-private-dns-zones/azurerm ~> 0.23` — correct, official AVM pattern, future-proof against new Azure services.
- Clean RG naming `rg-{sub}-{env}-{region}-plink-dns`.
- Standard naming vars + validations.
- Useful outputs: `private_dns_zone_resource_ids` map.

**Issues**:
- 🟠 Important: `enable_telemetry = false` is a deliberate AVM toggle — fine, but pin AVM version more tightly. `~> 0.23` allows 0.23.x only; given AVM ptns iterate fast (new privatelink zones added monthly), consider `~> 0.23` is OK but document the cadence to keep it bumped.
- 🟠 Important: `time_static.time` is declared but never used (no merged tags with `CreatedOn`) — RG tags use only `var.tags`.
- 🟡 Minor: no output for the AVM module's `virtual_network_links` ids; a consumer that wants to add an extra link cannot reference them.
- 🟡 Minor: missing `subscription_id` discriminator in name — fine because RG is sub-scoped, but note in README.

**Microsoft / Terraform official-docs cross-check (April 2026)**:
- AVM ptn 0.23.x covers all GA privatelink zones as of Q1 2026 (incl. `privatelink.cognitiveservices.azure.com`, `privatelink.openai.azure.com`, `privatelink.azconfig.io`, `privatelink.azurecontainerapps.io`).
- `azurerm_private_dns_zone_virtual_network_link` is the v4 resource (no rename). ✅
- Renovate should flag AVM bumps.

**Recommended changes**:
1. Remove the unused `time_static`, or use it in RG tags for consistency with other modules.
2. Document the AVM version bump cadence in README.
3. Expose pass-through output for VNet link IDs.

**Verdict**: ✅ OK

---

## Module: PrivateDnsZonesCorp

**Purpose**: Dedicated RG + corporate (non-privatelink) Azure Private DNS zones (e.g. `az.epttst.lu`) with many-to-many VNet links.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf. **README missing.**

**Strengths**:
- Smart `flatten`+`for` to compute the zone×VNet pairs map keyed `"<zone>-<linkname>"`. Stable plan-time keys (no unknown-key issue).
- `registration_enabled` is plumbed correctly per-link (use case: AKS DNS auto-reg).
- Consistent `common_tags` with `CreatedOn`.

**Issues**:
- 🔴 Critical: README missing — corporate-DNS zone selection (e.g. only on hub vs. spoke) is exactly the topic that needs documenting before a junior engineer trips on it.
- 🟠 Important: `azurerm_private_dns_zone_virtual_network_link.name` is `"link-${each.value.link_name}"` — same link name across zones is fine (different parent), but if one VNet appears under two zone groups with the same `link_name`, no collision because keys are zone-scoped — OK, but note in README.
- 🟠 Important: No validation on `var.zones` content (FQDN regex). A typo (`az_epttst.lu`) creates a broken zone silently.
- 🟡 Minor: missing `name` override variable; not critical since `zones` is the source of truth.
- 🟡 Minor: standard `workload` variable absent — purposeful (the zones are the "workload"), document it.

**Microsoft / Terraform official-docs cross-check (April 2026)**:
- `azurerm_private_dns_zone` and `azurerm_private_dns_zone_virtual_network_link` unchanged in v4 (no rename, no deprecation). ✅
- April 2026: Azure now supports up to 1000 VNet links per zone (was 100); this module scales with `for_each`. ✅

**Recommended changes**:
1. Write README explaining: which subscription owns this RG (hub `con`), naming, when to add a zone, gotcha vs. ALZ AVM zones.
2. Add an FQDN validation regex on `var.zones`.
3. Optional: emit `link_ids` output to allow downstream consumers to build dependency graphs.

**Verdict**: 🟡 Polish (README + validation)

---

## Module: DnsResolver

**Purpose**: Azure DNS Private Resolver (inbound + optional outbound) with optional forwarding ruleset and VNet links.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- `time_static` + `computed_name`/`name` pattern respected. Naming convention `dnspr-{sub}-{env}-{region}` matches CLAUDE.md.
- `enable_outbound`/`enable_ruleset` locals correctly gate optional resources.
- Clean inbound static-vs-dynamic IP toggle.
- Validations on every Azure resource ID and IPv4.

**Issues**:
- 🟠 Important: Subnet delegation `Microsoft.Network/dnsResolvers` is required on `inbound_subnet_id` and `outbound_subnet_id` — not validated and not documented; a missing delegation produces a long, unhelpful API error.
- 🟠 Important: `forwarding_rules` keys become rule names directly. Azure rule names accept `[A-Za-z][A-Za-z0-9-]{1,79}`. No validation — typos break apply.
- 🟠 Important: `domain_name` MUST end with `.` per Azure ARM contract; not validated. Add `endswith(d, ".")`.
- 🟠 Important: `ruleset_vnet_links` keys are used as link names (max 80 chars) — also no validation.
- 🟡 Minor: missing `workload` standard var — fine for a singleton hub resource.
- 🟡 Minor: encoding glitch in `main.tf` line 51: `"Inbound Endpoint ��� receives DNS queries..."` — UTF-8 mojibake from a stray em-dash. Fix to `—`.

**Microsoft / Terraform official-docs cross-check (April 2026)**:
- `azurerm_private_dns_resolver*` resources stable in v4 (no rename). [Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_resolver). ✅
- `azurerm_private_dns_resolver_virtual_network_link` scaling raised to 500 ruleset-VNet links per ruleset (Q4 2025 GA).
- No azapi needed.

**Recommended changes**:
1. Fix mojibake comment.
2. Add validation for `forwarding_rules` keys, `domain_name` trailing dot, `ruleset_vnet_links` keys.
3. README: warn about subnet delegation `Microsoft.Network/dnsResolvers`.

**Verdict**: 🟡 Polish

---

## Module: FlowLogs

**Purpose**: VNet Flow Logs (per-VNet `azurerm_network_watcher_flow_log`) with optional Traffic Analytics.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf. **README missing.**

**Strengths**:
- Correctly targets VNets via `target_resource_id = each.value.id`, NOT NSGs — this is the post-deprecation (Sep 2027) replacement (per [Microsoft NSG flow logs deprecation](https://learn.microsoft.com/azure/network-watcher/nsg-flow-logs-overview#nsg-flow-logs-retirement)). ✅
- Sets `version = 2` (Traffic Analytics requires v2).
- `dynamic` block for traffic analytics — clean opt-in.
- Validation on `interval_minutes` ∈ {10, 60}.

**Issues**:
- 🔴 Critical: README missing.
- 🟠 Important: `version` is a **reserved keyword** in some HCL contexts and a confusing field name. The provider attribute is literally `version` — fine — but consider exposing as a variable to allow future v3 (if MS releases). Right now it's hardcoded.
- 🟠 Important: `traffic_analytics.workspace_id` (workspace GUID, not resource ID) and `workspace_resource_id` are both required by API — that's a known Azure quirk; document in README so consumers aren't confused.
- 🟠 Important: No validation of `var.vnets[*].id` against the VNet resource ID regex. Pointing this at an NSG ID would now fail at apply (v4 enforces VNet target).
- 🟠 Important: Storage Account requirement — Microsoft mandates a storage account in the **same region** as the target VNet, with hierarchical namespace **disabled**. Not enforced/documented.
- 🟡 Minor: `retention_policy` is deprecated for VNet Flow Logs in favor of storage lifecycle management (April 2026 docs note: still supported, but migrating). Keep, but flag in README.

**Microsoft / Terraform official-docs cross-check (April 2026)**:
- [`azurerm_network_watcher_flow_log`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_watcher_flow_log) — `target_resource_id` accepts VNet, Subnet, or NIC IDs (NSG path deprecated). ✅
- v4 still emits a deprecation warning if target is an NSG.
- Traffic Analytics `interval_in_minutes` field name correct.

**Recommended changes**:
1. Write README + clearly document VNet-scoped Flow Logs (NSG path retired).
2. Validate `vnets[*].id` regex.
3. Add `outputs.names`/`ids` checked — both present. ✅
4. Add lifecycle note about retention_policy → storage lifecycle migration.

**Verdict**: 🟠 Rework (README missing, missing validations)

---

## Module: NetworkWatcher

**Purpose**: Azure Network Watcher per subscription, optional inline RG and management lock.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- Standard naming pattern with optional `workload` suffix.
- Optional inline RG creation pattern is clean.
- Lock support (CanNotDelete/ReadOnly) embedded.
- Correctly uses `azurerm_network_watcher` (singular, `_v2` is not a thing in v4).

**Issues**:
- 🟠 Important: Many subscriptions already have an auto-created `NetworkWatcherRG` + `NetworkWatcher_<region>`. If a caller doesn't disable the auto-create policy or import, this module collides at apply (`Resource already exists`). Document or expose `import` block.
- 🟠 Important: `validation` for `workload` regex `^[a-z][a-z0-9_-]{1,30}$` requires min 2 chars — README says default is `"network"` (7 chars) ✅, but pure-numeric workload like `"01"` would fail. Decide and document.
- 🟡 Minor: Two `time_static` reads (`merge` x2) — same value, no functional issue.
- 🟡 Minor: `lock` `name` default is `"lock-${kind}"` — good, but possibly collides if two locks of same kind exist on adjacent resources within the same scope. No issue here since lock scope = NW id.

**Microsoft / Terraform official-docs cross-check (April 2026)**:
- `azurerm_network_watcher` unchanged in v4. [Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_watcher).
- April 2026: Azure auto-deploys Network Watcher to every region; the policy `Deploy-Network-Watcher` is still active by default in ALZ — note this in README to avoid duplication.

**Recommended changes**:
1. README: warn about auto-created NetworkWatcher (and how to opt-out the platform policy or `terraform import`).
2. Allow `workload = null` to map to the no-suffix name (already supported via the conditional, just clarify).

**Verdict**: ✅ OK

---

## Module: DdosProtection

**Purpose**: DDoS Network Protection Plan (Standard tier).

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- `prevent_destroy` lifecycle — correct: DDoS Standard plan is paid hourly, accidental destroy + recreate has cost implications.
- Standard naming + optional `name` override.
- Slim, single-resource module — appropriate.

**Issues**:
- 🟠 Important: No `enabled`/SKU selector. Azure now exposes [DDoS IP Protection](https://learn.microsoft.com/azure/ddos-protection/ddos-protection-sku-comparison) as a per-public-IP cheaper SKU; this module only does the plan resource. OK by design but document scope.
- 🟠 Important: Tier (Standard vs. Network Protection vs. IP Protection) not configurable via `azurerm_network_ddos_protection_plan` — provider only supports the plan resource. Document.
- 🟡 Minor: `lifecycle { prevent_destroy = true }` is hard-set, which is annoying when intentionally tearing down sandbox/non-prod. Make it variable-driven (default true).
- 🟡 Minor: missing `id`/`name` on `output.resource` — exists, ✅.

**Microsoft / Terraform official-docs cross-check (April 2026)**:
- [`azurerm_network_ddos_protection_plan`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_ddos_protection_plan) unchanged in v4. ✅
- VNet-side `enable_ddos_protection` is configured on the VNet, not here — out of scope.

**Recommended changes**:
1. Variable-ize `prevent_destroy` (default `true`).
2. README: explain plan vs. IP Protection trade-off, expected ~$2944/month cost for Standard plan.

**Verdict**: ✅ OK (minor polish)

---

## Module: Ampls

**Purpose**: Azure Monitor Private Link Scope + scoped services + private endpoint.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- Correctly creates AMPLS, scoped services, **and** the PE in one place — coherent atomic unit.
- `lifecycle { ignore_changes = [private_dns_zone_group] }` honored (gotcha #10).
- `depends_on = [azurerm_monitor_private_link_scoped_service.this]` ensures PE is wired only after services are linked — correct ordering.
- `subresource_names = ["azuremonitor"]` is the right v4 spelling. ✅
- Validations on access modes, scoped service IDs, subnet ID.

**Issues**:
- 🔴 Critical: `private_ip_address` output reads `private_service_connection[0].private_ip_address` — same azurerm v4 quirk as PrivateEndpoint module: this attribute is often empty. Use `network_interface[0].private_ip_address`.
- 🟠 Important: Module does not adopt the standard naming-vars pattern (`subscription_acronym`, etc.); name is passed in directly. Inconsistent with rest of repo. Add the standard pattern (with `name` override fallback).
- 🟠 Important: Scoped services name `ampls-${each.key}` — Azure caps Scoped Service names at 64 chars and does NOT allow them to start with a number; your keys aren't validated. Add `^[a-z][a-z0-9-]{1,40}$` validation.
- 🟡 Minor: `private_dns_zone_ids` should validate each entry as a resource ID; currently `nullable = false` only.
- 🟡 Minor: README does not list the **4 required** privatelink zones for AMPLS (`monitor`, `oms.opinsights`, `ods.opinsights`, `agentsvc.azure-automation`, `blob.core.windows.net`) — your README example shows them, ✅.

**Microsoft / Terraform official-docs cross-check (April 2026)**:
- [`azurerm_monitor_private_link_scope`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_private_link_scope) — `ingestion_access_mode` and `query_access_mode` correct in v4. ✅
- April 2026: Azure added a 5th privatelink zone for AMA `privatelink.handler.control.monitor.azure.com` for Ingestion-from-DCR scenarios; document in README.
- AMPLS now allows max 300 scoped services (was 50).

**Recommended changes**:
1. Switch `private_ip_address` output to `network_interface[0]...`.
2. Add naming-vars pattern with `name` override.
3. Validate scoped service keys.
4. Bump README example with the new monitor handler zone.

**Verdict**: 🟡 Polish

---

## Module: AzureMonitorWorkspace

**Purpose**: Azure Monitor Workspace (managed Prometheus) with optional `prometheusMetrics` Private Endpoint.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- `time_static` + `computed_name`/`name` pattern. Naming `amw-{sub}-{env}-{region}-{workload}` matches convention.
- `public_network_access_enabled` defaults to `false` — secure-by-default. ✅
- Optional PE controlled by `subnet_id != null` — clean.
- `subresource_names = ["prometheusMetrics"]` correct in v4.
- `query_endpoint`, default DCE/DCR, and `private_endpoint_ip` outputs are exactly what the Grafana data source needs.
- `lifecycle { ignore_changes = [private_dns_zone_group] }` honored.

**Issues**:
- 🟠 Important: PE has **no `private_dns_zone_group` block at all** — relies entirely on ALZ DINE policy `Deploy-Private-DNS-prometheusMetrics` to wire `privatelink.<region>.prometheus.monitor.azure.com`. That works in this LZ, but it's an implicit dependency that should be documented in README. Otherwise the PE creates with no DNS until policy reconciles.
- 🟠 Important: `private_endpoint_ip` reads `private_service_connection[0].private_ip_address` — same quirk; switch to `network_interface[0].private_ip_address`.
- 🟠 Important: AMW does not need a custom DNS zone in the workspace's home region only; `privatelink.<region>.prometheus.monitor.azure.com` is region-specific. Note in README.
- 🟡 Minor: No validation that `workload` ≤ 8 chars — AMW name has no hard 24-char cap (limit ~63), so OK.
- 🟡 Minor: Variable `subscription_acronym` etc. all default to `null`, but if `name` is also `null`, computed_name becomes `amw-null-null-null-01`. Add a cross-validation.

**Microsoft / Terraform official-docs cross-check (April 2026)**:
- [`azurerm_monitor_workspace`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_workspace) — unchanged in v4, exposes `default_data_collection_endpoint_id` / `default_data_collection_rule_id`. ✅
- April 2026: AMW now supports CMK encryption via `identity { type = "SystemAssigned" }` + `customer_managed_key { ... }`. Not in this module — feature gap if security baseline requires CMK.
- PE subresource `prometheusMetrics` (camelCase) correct.

**Recommended changes**:
1. Switch `private_endpoint_ip` to `network_interface[0]`.
2. Add a `precondition` lifecycle on the AMW resource: when `name == null` then all naming vars must be non-null.
3. README: explicitly note the DNS zone group is owned by ALZ DINE.
4. Optional: add CMK support (variable `customer_managed_key`).

**Verdict**: 🟡 Polish

---

## Final Verdict Table

| # | Module | Verdict | Top action |
|---|--------|---------|------------|
| 1 | PrivateEndpoint | ✅ OK | Drop unused data block; fix `private_ip_addresses` to read `network_interface[0]`. |
| 2 | PrivateDnsZones | ✅ OK | Remove unused `time_static`; document AVM bump cadence. |
| 3 | PrivateDnsZonesCorp | 🟡 Polish | Write README; FQDN regex on `zones`. |
| 4 | DnsResolver | 🟡 Polish | Fix mojibake; validate rule keys + `domain_name` trailing dot; document subnet delegation. |
| 5 | FlowLogs | 🟠 Rework | Write README; validate `vnets[*].id`; document storage SA constraints. |
| 6 | NetworkWatcher | ✅ OK | README warn about auto-created NW collision. |
| 7 | DdosProtection | ✅ OK | Variable-ize `prevent_destroy`; cost note in README. |
| 8 | Ampls | 🟡 Polish | Fix `private_ip_address` output; add naming-vars pattern; validate scoped service keys. |
| 9 | AzureMonitorWorkspace | 🟡 Polish | Fix `private_endpoint_ip` output; precondition on `name`/naming vars; README DNS zone note. |

**Aggregate**: 4 ✅ / 4 🟡 / 1 🟠 / 0 🔴.
**Cross-cutting**: (a) Three modules read `private_service_connection[0].private_ip_address` for the PE IP — switch all to `network_interface[0].private_ip_address` to avoid empty-output edge cases under azurerm v4. (b) Two modules (`PrivateDnsZonesCorp`, `FlowLogs`) lack README — required before tagging a release.

Reference docs:
- [azurerm v4 PE](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint)
- [azurerm v4 Flow Log](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_watcher_flow_log)
- [azurerm v4 DDoS plan](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_ddos_protection_plan)
- [azurerm v4 DNS Resolver](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_resolver)
- [azurerm v4 AMPLS](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_private_link_scope)
- [azurerm v4 AMW](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_workspace)
- [NSG Flow Logs retirement (Sep 2027)](https://learn.microsoft.com/azure/network-watcher/nsg-flow-logs-overview#nsg-flow-logs-retirement)
- [AVM ptn private link DNS zones](https://github.com/Azure/terraform-azurerm-avm-ptn-network-private-link-private-dns-zones)
