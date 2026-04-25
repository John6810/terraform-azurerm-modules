# Review A2 — Network L2/L3 (9 modules)

Scope: `Vnet`, `VNetPeering`, `SubnetWithNsg`, `NSG`, `RouteTable`, `ApplicationGateway`, `NatGateway`, `vpn`, `vwan`.
Provider baseline: azurerm `~> 4.0` (April 2026), azapi `~> 2.x`. Region: `germanywestcentral`. Topology: hybrid hub-and-spoke (Palo OBEW NVA in nprd, vWAN legacy in prod), all spokes egress through Palo ILB (PROD `10.238.200.36` / NPRD `10.239.200.36`).

---

## Module: Vnet

**Purpose**: Azure Virtual Network with optional inline subnets, IPAM pool, DDoS plan, management lock.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- Standard naming pattern (`time_static` + `computed_name` + `name`) correctly applied.
- Inputs properly validated (regex on naming components, lock kind, subnet `address_prefixes` non-empty).
- Inline-subnet path is a clean superset of `azurerm_subnet` features (delegations, IPAM, NAT GW, RT, NSG associations).
- DDoS plan and IPAM pool are wrapped in correct `dynamic` blocks (set only when relevant).
- README is complete and shows both standalone and Terragrunt usage.

**Issues**:
- 🔴 **Two-step NSG association breaks Azure Policy "Subnets must have NSG" (Deny)**. The inline-subnet path creates `azurerm_subnet` first, then `azurerm_subnet_network_security_group_association` — exactly the pattern `SubnetWithNsg` was created to avoid. If consumers actually use `var.subnets` with `nsg_id`, the policy will block them. Either remove the inline-subnet feature or rewrite via `azapi_resource` like `SubnetWithNsg`.
- 🟠 `address_space` is `nullable = true` with `default = null`, but the resource requires it. Either make it required or validate non-empty. Today `terragrunt apply` with no address_space fails at API time, not plan time.
- 🟠 No `lifecycle { prevent_destroy = true }` for hub VNets. Hub VNet destroy cascades to peerings/PEs/etc. Recommend exposing a `prevent_destroy` toggle or hard-coding for hubs.
- 🟠 v4: `enable_ddos_protection` is fine, but the inner block `enable` + `id` is the v4 syntax — OK. Confirm `private_endpoint_network_policies` accepts the v4 string values `Disabled` / `Enabled` / `NetworkSecurityGroupEnabled` / `RouteTableEnabled` (no validation on this input — add one).
- 🟡 `output.tags` is redundant (callers can read `resource.tags`).
- 🟡 `formatdate("DD-MM-YYYY hh:mm", timeadd(time_static.time.id, "1h"))` — the +1h offset is to align UTC→CET, but this breaks across DST. Use UTC and document, or compute via `timestamp()` only outside state.

**MS / Terraform docs cross-check**:
- azurerm v4 reference: <https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network>. `flow_timeout_in_minutes` (idle flow timeout) and `encryption { enforcement }` are v4 properties not exposed here — useful for hub VNets.
- VNet Flow Logs (the codebase note says `FlowLogs` module) — confirmed correct: NSG flow logs are deprecated and migrate to `azurerm_network_watcher_flow_log` (target_resource_id = VNet ID). Vnet module rightly stays out of it.
- `bgp_community` (when peered to ExpressRoute) not exposed.

**Recommended changes**:
1. Drop the inline-subnet-with-NSG path or migrate it to azapi to comply with the Deny policy.
2. Add `flow_timeout_in_minutes` and `encryption` block as optional inputs.
3. Validate `private_endpoint_network_policies` enum.
4. Fix or remove the `+1h` `CreatedOn` tag.

**Verdict**: 🟠 Rework (the NSG-policy conflict on the inline path is real).

---

## Module: VNetPeering

**Purpose**: Creates one-direction VNet peerings via a map (caller is responsible for the reverse).

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- Minimal, focused, validates `remote_virtual_network_id` shape.
- Map-based, so adding peerings is a single line in caller.
- Sensible defaults (`allow_forwarded_traffic = true`, `allow_virtual_network_access = true`, `allow_gateway_transit = false`, `use_remote_gateways = false`).

**Issues**:
- 🟠 **`triggers_on_forced_traffic` / `local_subnet_names` / `remote_subnet_names` not exposed.** azurerm v4.x introduced (April 2025+) the ability to peer specific subnets and to force re-evaluation when remote VNet address space changes. For ALZ this is increasingly important when spokes do dynamic `address_space` updates.
- 🟠 No `peering_sync_state` handling. v4 also exposes `peer_complete_vnets` (default `true`) — when `false`, you must list `local_subnet_names` and `remote_subnet_names`. Not exposed here, so callers can't use subnet-scoped peering.
- 🟠 No `time` provider; not strictly needed but means peerings get no `CreatedOn` tag (peerings can't be tagged anyway, so OK).
- 🟡 Module name `VNetPeering` (PascalCase) is inconsistent with `vpn` / `vwan` (lower-case). Pick one.
- 🟡 `outputs.resources` exposes the whole resource — that's fine, but `outputs.names` would mirror other modules.

**MS / Terraform docs cross-check**:
- azurerm v4 reference: <https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering>. New in v4: `peer_complete_vnets`, `local_subnet_names`, `remote_subnet_names`, `only_ipv6_peering_enabled`. None exposed.
- For vWAN topology in prod, peerings should NOT exist between spokes (vWAN handles transit). The module doesn't enforce this — caller's responsibility, but worth a note in README.

**Recommended changes**:
1. Add optional `peer_complete_vnets`, `local_subnet_names`, `remote_subnet_names`, `only_ipv6_peering_enabled`.
2. Add a `names` output.
3. README: warn that this module is for hub-and-spoke (Palo OBEW), NOT for vWAN-managed connectivity.

**Verdict**: 🟡 Polish.

---

## Module: SubnetWithNsg

**Purpose**: Creates subnets with NSG (and optional RT, NAT GW, delegation) in a single PUT via `azapi_resource`, to satisfy Deny policy on subnet-without-NSG.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- Correctly addresses the policy gotcha (#1 in CLAUDE.md). The single-PUT approach is the right pattern.
- Map keyed by **full subnet name** matches gotcha #1 — README explicitly calls it out.
- Validates CIDR shape and uniqueness.
- Uses recent API version `2025-03-01`.

**Issues**:
- 🔴 **No `nat_gateway_id` support**. The `Vnet` module exposes it but `SubnetWithNsg` doesn't — silent feature gap. If the codebase standardizes on this module (as the policy forces), spokes that need a NAT GW (untrust subnets, AKS egress) cannot use it.
- 🔴 **No `service_endpoints` and no `private_endpoint_network_policies`** in the body. The `azapi` body must include `serviceEndpoints` and `privateEndpointNetworkPolicies` / `privateLinkServiceNetworkPolicies` — currently absent. Subnets created here get default behavior (`privateEndpointNetworkPolicies=Enabled`), which BLOCKS PE creation in some contexts. Critical for `pe-*` subnets.
- 🟠 Only one `delegation` per subnet — Azure supports multiple. The `Vnet` module supports a list. Inconsistency.
- 🟠 No `lifecycle { ignore_changes = [body.properties.privateEndpointNetworkPolicies] }` if PEs flip the flag. With ALZ DINE this can cause perpetual diff (gotcha #10 mentions PE-side; subnet-side has its own variant).
- 🟠 No retry/timeouts override — when applying `routeTable` association on a subnet that has an NSG-flow-log dependency, the API can take >5 min.
- 🟡 No `default_outbound_access_enabled` validation; defaults to `false` which is correct for ALZ (gotcha — Azure default flips to false in Sept 2025; module locks it explicitly which is good).

**MS / Terraform docs cross-check**:
- ARM API: `Microsoft.Network/virtualNetworks/subnets@2025-03-01` — supports `serviceEndpoints`, `privateEndpointNetworkPolicies` (`Enabled|Disabled|NetworkSecurityGroupEnabled|RouteTableEnabled`), `privateLinkServiceNetworkPolicies`, `natGateway`, `ipAllocations`, `defaultOutboundAccess`, `sharingScope`. <https://learn.microsoft.com/en-us/azure/templates/microsoft.network/virtualnetworks/subnets>
- `azapi` provider 2.x — recommend `replace_triggers_external_values` if NSG ID changes.

**Recommended changes**:
1. Add `nat_gateway_id`, `service_endpoints`, `private_endpoint_network_policies`, `private_link_service_network_policies` to the body.
2. Allow list of delegations.
3. Add `lifecycle { ignore_changes = [body.properties.privateEndpointNetworkPolicies] }` (opt-in flag).
4. Add a `names` output (subnet name => name) for symmetry.

**Verdict**: 🟠 Rework — feature parity with `Vnet` inline subnets is a hard requirement.

---

## Module: NSG

**Purpose**: Creates one or more NSGs (map-keyed by short workload key) with inline `security_rule`s.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- Map-of-NSGs lets a single module deploy all spoke NSGs in one shot.
- Validates direction, access, protocol, priority bounds.
- No standalone `azurerm_network_security_rule` (which is mutually exclusive with inline rules) — correct v4 pattern.

**Issues**:
- 🔴 **No `time_static` consistency check**: the file uses `time_static.time.id` but the resource has only `tags`, not `lifecycle` — fine. However the `time_static.time.id` recomputes on apply if state is wiped; tag value of `CreatedOn` will drift. Already pervasive across modules.
- 🟠 **No `name` override input** like other modules — always computed. Inconsistent with `Vnet` / `RouteTable`.
- 🟠 **No diagnostic-settings hook**. NSG flow logs are deprecated 2026; the codebase routes flow logs via the `FlowLogs` module pointing at the **VNet** (correct, per April 2026 deprecation). Confirm the README says "do not enable NSG flow logs here." It does not.
- 🟠 Missing input for `accelerated_networking` flag at NSG-rule level (`source_application_security_group_ids` is there — good). Consider adding `inbound_security_rules_enabled` / `outbound_security_rules_enabled` toggles when supported.
- 🟠 No validation that `priority` values are unique within an NSG — Azure rejects duplicates and the error is opaque.
- 🟡 Output `names` is map of key → name; missing `name_to_id` reverse lookup that consumers occasionally need.

**MS / Terraform docs cross-check**:
- azurerm v4 reference: <https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group>. v4 dropped `network_security_rule` inline ↔ standalone duality — module is on the right side.
- VNet Flow Logs (replacement for NSG flow logs): <https://learn.microsoft.com/en-us/azure/network-watcher/vnet-flow-logs-overview> — Confirmed: NSG flow logs deprecated by Sept 2027; new deployments must use VNet flow logs. Module abstains correctly.

**Recommended changes**:
1. Add optional `name` map override to skip the computed name.
2. Validate priority uniqueness per NSG (Terraform-side).
3. Add the missing `workload`/per-NSG suffix variability — currently the NSG name uses the map key as workload, but no `var.workload` exists, breaking convention drift.
4. README: explicitly say "flow logs go in the FlowLogs module against the VNet, not here."

**Verdict**: 🟡 Polish.

---

## Module: RouteTable

**Purpose**: Single Route Table with a map of routes, optional lock, BGP propagation toggle.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- Clean validations on `next_hop_type` and the `next_hop_in_ip_address` ↔ `VirtualAppliance` constraint (both directions).
- `bgp_route_propagation_enabled` (v4 rename from `disable_bgp_route_propagation`) used correctly.
- Lock support, name override, full naming convention.
- Per gotcha #5, this module is the natural place for `0.0.0.0/0 → 10.238.200.36 / 10.239.200.36`. README example would benefit from showing it.

**Issues**:
- 🟠 No validation that `address_prefix` is a valid CIDR or Azure Service Tag. A typo silently goes to the API.
- 🟠 No `prevent_destroy` toggle. RT deletion in a spoke breaks egress through Palo. Recommend hub-RT default = `prevent_destroy = true`.
- 🟠 No way to associate the RT with subnets in the same module. Acceptable given separation of concerns, but README should explicitly point at `SubnetWithNsg` / `Vnet`.
- 🟡 `output.routes` returns the set; for large RTs the diff is noisy. Consider `route_names` / `next_hops` projections.

**MS / Terraform docs cross-check**:
- azurerm v4 reference: <https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route_table>. The renamed property `bgp_route_propagation_enabled` is the v4 name (was `disable_bgp_route_propagation` in v3 and inverted) — module is correct.
- New (azurerm 4.10+, late 2025): `route` block now supports `has_bgp_override` for VirtualNetworkGateway routes. Not exposed.

**Recommended changes**:
1. Add CIDR / service-tag validation on `address_prefix`.
2. Add `has_bgp_override` to the route object.
3. README: include the canonical Palo default-route example for both PROD and NPRD.

**Verdict**: ✅ OK with minor polish.

---

## Module: ApplicationGateway

**Purpose**: Application Gateway WAF_v2 with WAF Policy (DRS 2.1 + Bot 1.0), autoscale, optional public IP, default placeholder backend.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- WAF Policy attached via `firewall_policy_id` (the modern path; per-listener WAF config inside AppGW is deprecated in v4).
- `lifecycle { ignore_changes }` of dynamic backend/listener/rule/probe/url_path/ssl — perfect for AGIC and external CD pipelines.
- `availability_zones = ["1","2","3"]` default is correct for `germanywestcentral` (3 zones available).
- Public IP gated by `create_public_ip` with PoC warning on the tag — good safety guard.

**Issues**:
- 🔴 **`http_listener` named `default-http-listener` listens on port 80 with no rewrite/redirect to HTTPS, no TLS cert.** This is fine as a placeholder under `ignore_changes`, but if AGIC is *not* used the AppGW is created with a permanently insecure default. Recommend creating it bound to a 444/closed port or making the default rule-set toggleable.
- 🟠 No `force_firewall_policy_association = true`. Without it, listener-level WAF can override. v4 best practice is to set `force_firewall_policy_association = true`.
- 🟠 WAF policy uses `Microsoft_DefaultRuleSet 2.1` which is current, but **CRS 3.2 / DRS 2.1 has a successor `Microsoft_DefaultRuleSet 2.2`** (GA 2025-Q4) — should at minimum be a variable.
- 🟠 No `ssl_policy { policy_type = "Predefined" policy_name = "AppGwSslPolicy20220101S" }` — by default AppGW uses an old SSL policy. Should default to `AppGwSslPolicy20220101S` (TLS 1.2+ strong ciphers).
- 🟠 No `identity` block for KV-managed certificates. Production AppGW always wants UAMI for cert pulls.
- 🟠 No `enable_http2` (`http2_enabled = true`) — modern default should be on.
- 🟠 `frontend-private` always created even when Palo fronts it — fine, but no `private_link_configuration` for PE-mode.
- 🟡 `output.private_ip_address` uses `[0]` which fails plan with `for_each` count differences if listener changes shape. Use `try()`.
- 🟡 `tags` apply both to PIP, WAF policy, AppGW — duplicating `CreatedOn` three times via three `time_static`s would drift; here a single `time_static.time` is reused — good.

**MS / Terraform docs cross-check**:
- azurerm v4 reference: <https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_gateway>. New in v4.x: `force_firewall_policy_association`, `global { request_buffering_enabled, response_buffering_enabled }`, `private_link_configuration` GA.
- WAF policy: <https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/web_application_firewall_policy>. DRS 2.2 GA late 2025.
- Application Gateway for Containers (AGC) is the modern AKS replacement (still preview-ish at April 2026, azapi-only) — not in scope here.

**Recommended changes**:
1. Add `force_firewall_policy_association = true` and `enable_http2`.
2. Expose WAF rule-set version, mode, and a `managed_rule_overrides` / `custom_rules` list.
3. Add `ssl_policy` with secure default.
4. Add `identity` block (UAMI) for KV-cert pulls.
5. Wrap `output.private_ip_address` in `try()`.
6. README: confirm prod uses `create_public_ip = false` and Palo OBEW DNAT to private IP.

**Verdict**: 🟠 Rework.

---

## Module: NatGateway

**Purpose**: NAT Gateway StandardV2 with associated public IP via `azapi_resource` (azurerm doesn't yet support StandardV2).

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- Correct decision to use `azapi`: as of April 2026 azurerm `~> 4.0` still only supports `Standard` for `azurerm_nat_gateway`; StandardV2 is azapi-only.
- API version `2025-03-01` is current.
- Zone-redundant by default (`["1","2","3"]`) — matches `germanywestcentral` zones.
- Good idle timeout validation (4–120 min).

**Issues**:
- 🟠 **The Palo OBEW spokes have NO public IPs (per ALZ design).** This module is therefore only valid in either: (a) the untrust segment of the Palo cluster (yes), or (b) outside the OBEW spokes entirely. README should explicitly call this out — currently it doesn't.
- 🟠 Single PIP only — StandardV2 supports multi-PIP / public-IP-prefix attachments. No `public_ip_prefix_ids` / `public_ip_addresses` (additional) input.
- 🟠 No `lock` support, no `tags` validation, no `prevent_destroy`. NAT GW destroy on the untrust path will break Palo egress.
- 🟠 No cross-check that `var.zones` matches the PIP `zones`. Today both are wired to the same `var.zones`, so OK, but if a user sets only one zone, StandardV2 SLA drops — should warn.
- 🟡 PIP DNS label, idle-timeout for PIP, DDoS plan attachment on PIP — none exposed.
- 🟡 `parent_id` taken as RG ID — consistent with azapi pattern but inconsistent with sibling modules that take `resource_group_name`.

**MS / Terraform docs cross-check**:
- ARM API: `Microsoft.Network/natGateways@2025-03-01` and `Microsoft.Network/publicIPAddresses@2025-03-01`. <https://learn.microsoft.com/en-us/azure/templates/microsoft.network/natgateways>
- StandardV2 NAT GW: GA Oct 2025. Properties: `zones[]`, `publicIpAddresses[]`, `publicIpPrefixes[]`, `idleTimeoutInMinutes` (max 120). Per-zone SLA 99.99 vs cross-zone 99.95.
- azurerm tracking issue: <https://github.com/hashicorp/terraform-provider-azurerm/issues/27259> — confirmed not yet in azurerm. azapi is the right call.

**Recommended changes**:
1. Add `public_ip_prefix_ids` and additional-PIP support.
2. Add `lock` block.
3. README: explicit "where to deploy in this LZ" guidance (Palo untrust only).
4. Take `resource_group_name` instead of (or alongside) `resource_group_id` for sibling-module symmetry.

**Verdict**: 🟡 Polish.

---

## Module: vpn

**Purpose**: VNet-attached VPN Gateway (S2S + optional P2S) with multiple `local_network_gateways` and BGP.

**Files inspected**: version.tf, variables.tf, main.tf, output.tf, README.md.

**Strengths**:
- Reasonable SKU validation (covers VpnGwNAZ).
- Active-active and BGP both correctly gated.
- `vpn_client_configuration` covers AAD, root cert, revoked cert.
- `local_network_gateways` keyed map → automatic naming `lng-{key}` and `conn-{key}`.

**Issues**:
- 🔴 **Zones bug**: `endswith(var.sku, "AZ") ? ["1","2","3"] : null`. PIP `zones` for `Standard` SKU is **not optional anymore** in v4 — it must be explicit list or `null`, and the `null` produces a non-zonal PIP (regional). For non-AZ SKUs deployed in zoned regions you may want zone `["1"]`. Confirm intent: today a VpnGw1 (non-AZ) will get a non-zonal PIP, which is fine but undocumented.
- 🔴 **`shared_key` is sensitive but exposed via `var.local_network_gateways` whose top-level type is `sensitive = true`** — good — but the **resource attribute** ends up in plan output. v4 does mask it; OK. However connection PSK is set via `each.value.shared_key` directly with no length/charset validation — Azure rejects PSK <1 or with non-printable chars silently.
- 🔴 **No `custom_route` / `custom_bgp_addresses` on the gateway**. Active-active with BGP normally requires per-instance `custom_bgp_addresses` (override of APIPA). Module advertises BGP support but cannot fully express it.
- 🟠 v4: `enable_bgp` is the correct property (`enable_bgp` was renamed to keep its name in v4). However `vpn_type` and `generation` are conditionally set to `null` when `type=ExpressRoute` — but for ER you'd use `azurerm_express_route_gateway`, not VNG. ER path here is dead code — remove it.
- 🟠 No `dpd_seconds` at gateway level (only on connection). Also no `policy_based_traffic_selector` toggle on `azurerm_virtual_network_gateway` for vendor compatibility.
- 🟠 `vpn_client_configuration.aad_*` defaults to null — combination of AAD + root cert is an Azure constraint (mutually exclusive). Validate at module level.
- 🟠 No `private_ip_address_enabled` / `remote_vnet_traffic_enabled` / `virtual_wan_traffic_enabled` v4 toggles.
- 🟠 README example shows `VpnGw1` but this module's `endswith("AZ")` zone logic only kicks in for the AZ variants — defaults give non-zonal which contradicts ALZ best-practice.
- 🟡 `time` provider not in `version.tf`; not used either, but no `CreatedOn` tag — inconsistent with siblings.
- 🟡 Outputs missing simple `id` and `name` — uses `vpn_gateway_id` etc. Inconsistent.

**MS / Terraform docs cross-check**:
- azurerm v4 reference: <https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway>. v4 added `private_ip_address_enabled`, `remote_vnet_traffic_enabled`, `virtual_wan_traffic_enabled`, `bgp_route_translation_for_nat_enabled`, and renamed `policy_group { is_default = true }` blocks for granular P2S. None exposed.
- Connection: <https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway_connection>. `egress_nat_rule_ids` / `ingress_nat_rule_ids` for VNG NAT rules — absent.
- Generation2 SKUs (VpnGw4/5 with AZ) recommended for new deployments.

**Recommended changes**:
1. Drop the `type = "ExpressRoute"` branch — use the dedicated ER-gateway resource.
2. Default SKU to `VpnGw2AZ` (Generation2) and require zoned PIP.
3. Expose `custom_bgp_addresses` per ip_configuration.
4. Add NAT rule association (egress/ingress).
5. Validate AAD ↔ root-cert exclusivity.
6. Standardize outputs: `id`, `name`, `public_ip`, `bgp`.

**Verdict**: 🟠 Rework.

---

## Module: vwan

**Purpose**: Virtual WAN + virtual hubs + VPN/ER/Firewall in hubs + VPN sites + S2S/P2S connections + BGP connections (NVA).

**Files inspected**: version.tf, variables.tf, variables-hubs.tf, variables-vpn.tf, main.tf, hubs.tf, gateways.tf, vpn.tf, output.tf, README.md.

**Strengths**:
- Well-decomposed across files (`hubs.tf`, `gateways.tf`, `vpn.tf`).
- `azurerm_virtual_hub_route_table` uses v4 syntax with `destinations_type = "CIDR"` and `next_hop_type = "ResourceId"` — correct.
- VPN sites + links + per-link ipsec_policy fully expressed.
- Outputs surface BGP IPs and tunnel public IPs, which is the actual data ops needs for CPE config.
- Firewall, ER, VPN gateways are all gated by `optional` blocks per hub.

**Issues**:
- 🔴 **No Routing Intent / Routing Policies support**. Since vWAN routing-intent GA (Oct 2024), routing intent is the recommended pattern for inserting Azure Firewall / NVA into vWAN traffic flow. The module exposes `azurerm_virtual_hub_route_table` only, which is the legacy custom route-table model. For "secured virtual hub with NVA" patterns this is a hard miss. Need `azurerm_virtual_hub_routing_intent` (azurerm 4.5+) or azapi.
- 🔴 **No SecureHub / Premium Firewall policy guidance**. The hub firewall block defaults `sku_tier = "Standard"` and `threat_intel_mode = "Alert"`. Premium tier (TLS inspection, IDPS) is the modern default for prod.
- 🟠 The output `vpn_gateway_public_ips` indexes `tunnel_ips[1]` — fragile. Some BGP modes return only one tunnel IP, blowing up. Use `try(tolist(…)[1], tolist(…)[0])`.
- 🟠 Likewise `bgp_settings[0].instance_0_bgp_peering_address[0].default_ips` — wrap in `try()`.
- 🟠 `azurerm_firewall.hub_firewalls.virtual_hub.public_ip_count = 1` is hard-coded — production hubs typically need 2 to ride zone failures.
- 🟠 `routes` list per hub builds a single `defaultRouteTable` only when `length(v.routes) > 0`. If you ever attach a custom route-table separately you'll collide. README doesn't warn.
- 🟠 `azurerm_virtual_hub_bgp_connection` exists but `virtual_network_connection_id` is taken from `azurerm_virtual_hub_connection.connections`, requiring the `var.virtual_hub_connection_key` lookup. Good. But no validation the connection key exists.
- 🟠 `vpn_site` has `address_cidrs` AND `link.bgp` — when BGP is on, `address_cidrs` should be omitted; module doesn't enforce.
- 🟡 `var.name` is not validated for length/charset — vWAN max name 80 chars, but children like `vpngw-{key}` can exceed downstream limits.
- 🟡 No `time_static` / `CreatedOn` tag — inconsistent with the rest of the repo.
- 🟡 `vpn_shared_key` declared but unused (not wired to `vpn_link.shared_key`). Dead variable.

**MS / Terraform docs cross-check**:
- azurerm v4 reference: <https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_hub>, <https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_hub_routing_intent> (4.5+).
- vWAN Routing Intent: <https://learn.microsoft.com/en-us/azure/virtual-wan/how-to-routing-policies>. Two policies: "Internet Traffic" and "Private Traffic" each pointing at the AzFW. This is what production vWAN deployments need.
- Azure Firewall Premium in vWAN: <https://learn.microsoft.com/en-us/azure/firewall-manager/secured-virtual-hub>. SKU `AZFW_Hub` + `Premium` tier.
- Office 365 breakout: deprecated as of 2024 — `office365_local_breakout_category` has no real effect; should probably be marked deprecated in description.

**Recommended changes**:
1. Add `azurerm_virtual_hub_routing_intent` resource gated by an optional per-hub `routing_intent` block (private+internet policies).
2. Default firewall `public_ip_count` to 2 and surface as variable.
3. Wrap fragile output expressions in `try()`.
4. Drop or wire `var.vpn_shared_key`.
5. README: clarify legacy custom-RT vs routing-intent decision tree.
6. Add DDoS, lock, and `prevent_destroy` toggles for the vWAN itself.

**Verdict**: 🟠 Rework — routing intent is too important to be missing in 2026.

---

## Final verdict summary

| # | Module | Verdict | Top concern |
|---|--------|---------|---|
| 1 | Vnet | 🟠 Rework | Inline-subnet path collides with NSG-Deny policy |
| 2 | VNetPeering | 🟡 Polish | Missing `peer_complete_vnets` / subnet-scoped peering |
| 3 | SubnetWithNsg | 🟠 Rework | No `nat_gateway_id`, no `service_endpoints`, no `private_endpoint_network_policies` |
| 4 | NSG | 🟡 Polish | No `name` override, no priority-uniqueness validation |
| 5 | RouteTable | ✅ OK | Add CIDR validation + `has_bgp_override` |
| 6 | ApplicationGateway | 🟠 Rework | No `force_firewall_policy_association`, no SSL policy, no UAMI |
| 7 | NatGateway | 🟡 Polish | Single PIP only; no `public_ip_prefix_ids` |
| 8 | vpn | 🟠 Rework | Dead ER branch; no `custom_bgp_addresses`; no v4 traffic toggles |
| 9 | vwan | 🟠 Rework | No Routing Intent (post-Oct 2024 best practice); fragile outputs |

**Cross-cutting recommendations**:
- Standardize output names (`id`, `name`, plus domain) across all modules — vpn / vwan currently drift.
- Standardize `resource_group_name` vs `resource_group_id` input convention (azapi modules want ID, azurerm wants name; document the contract).
- The `time_static` + `+1h` `CreatedOn` tag pattern is shared across most modules — broken across DST. Either drop, or use UTC.
- Adopt `prevent_destroy` toggles on stateful resources (VNet, RT, AppGW, VPN GW, vWAN) via a `var.prevent_destroy` boolean — currently absent everywhere.
- Add validation across all `*_id` inputs (regex resource-ID shape) — partially present, not consistent.
- Deprecation watch: NSG flow logs (Sept 2027), `Microsoft_DefaultRuleSet 2.1` (succeeded by 2.2), `office365_local_breakout_category` (no-op).
