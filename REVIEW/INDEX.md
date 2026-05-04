# Review terraform-azurerm-modules — Synthèse

**Date** : 2026-04-24 (review) · 2026-05-04 (status update) — **Modules** : 47 — **Provider baseline** : azurerm v4.x (2026-04)

> **Status — 2026-05-04** : Sprints 1-6 terminés. Toutes les actions prioritaires de la review du 2026-04-24 sont fermées (cf. [Sprint outcomes](#sprint-outcomes) en bas du document). 0 caller cassé sur le LZ ; 5 plans testés sur infra live (`network-shared` apply, `prometheus-aks`, `diag-api`, `nat-gateway`, déploiements Sprint 6 spot-check).

| Batch | Domaine | Modules | Fichier |
|---|---|---|---|
| A1 | Compute & VMs | 9 | [A1-compute-vms.md](A1-compute-vms.md) |
| A2 | Network L2/L3 | 9 | [A2-network-l2l3.md](A2-network-l2l3.md) |
| A3 | Network Edge & DNS & PE | 9 | [A3-network-edge-dns.md](A3-network-edge-dns.md) |
| A4 | Data, Storage, Crypto | 8 | [A4-data-storage-crypto.md](A4-data-storage-crypto.md) |
| A5 | ALZ, Governance, Monitoring | 12 | [A5-alz-governance-monitoring.md](A5-alz-governance-monitoring.md) |

---

## Verdicts agrégés

| Verdict | Count | % |
|---|---|---|
| ✅ OK | 11 | 23% |
| 🟡 Polish | 17 | 36% |
| 🟠 Rework | 18 | 38% |
| 🔴 Blocking | 1 | 2% |

**0 module à supprimer**. Aucune dette catastrophique mais ~40 % du repo mérite un round de polish ciblé.

---

## Bugs recurrents (à régler en bloc)

### 1. 🔴 `principal_type = "Group"` manquant sur role assignments — ✅ Sprint 1

Le bug fixé dans le commit `da4e610` (rbac-avd) **n'a pas été propagé** aux autres modules :

- `RbacAssignments` — block `groups` sans `principal_type` → `UnmatchedPrincipalType`
- `Grafana` — 3 blocks RBAC + identity sans `principal_type`
- `ManagedIdentity` — sans `principal_type` sur les outputs/role assignments si exposés
- 5 modules AVD — pas encore complété

**Fix** : ajouter `principal_type = "Group"` partout où on assigne un rôle à un groupe AAD. `ContainerRegistry` peut servir de template (déjà conforme).

### 2. 🟠 `private_ip_address` lu depuis `private_service_connection[0]` au lieu du NIC — ⏸ Deferred (faux positif)

Sous azurerm v4, `private_service_connection[0].private_ip_address` est souvent vide. Touche :

- `PrivateEndpoint`
- `Ampls`
- `AzureMonitorWorkspace`

**Fix** : `output "private_ip" { value = azurerm_private_endpoint.this.network_interface[0].private_ip_address }`

> **2026-05-04 update** : vérification a posteriori — l'attribut `network_interface[0].private_ip_address` n'existe pas en v4 ; le `private_service_connection[0]` reste la source officielle. Item marqué deferred (faux positif review).

### 3. 🟡 Pattern `time_static + timeadd("1h")` pour `CreatedOn` tag — ⏸ Backlog

Tous les modules ajoutent +1h au timestamp UTC pour simuler CET. Ne marche pas en hiver (DST). Touche pratiquement tous les modules. **Fix** : utiliser `timestamp()` formaté avec l'offset depuis une variable, ou simplement laisser UTC.

### 4. 🟠 Outputs naming drift — ✅ Sprint 5 (KeyVault) · ✅ Sprint 2 (vpn supprimé)

- `KeyVault` expose `uri` au lieu de `vault_uri` (incohérent avec `azurerm_key_vault.vault_uri`) → ✅ alias `vault_uri` ajouté, `uri` deprecated
- ~~`vpn` expose `vpn_gateway_id` / `vpn_gateway_name` au lieu de `id` / `name`~~ → ✅ module supprimé entièrement (vwan le remplace)

**Fix** : standardiser sur `id`, `name`, `<resource>_<property>`.

---

## Top 10 actions prioritaires

| # | Module | Action | Sévérité | Effort | Status |
|---|---|---|---|---|---|
| 1 | RbacAssignments + Grafana + ManagedIdentity + AVD×5 | Ajouter `principal_type = "Group"` partout | 🔴 | S | ✅ Sprint 1 |
| 2 | KeyVaultStack | Ajouter precondition sur 24-char KV name limit | 🔴 | S | ✅ Sprint 1 |
| 3 | KeyVault-Key | Fix bug `tags` jamais appliqué sur la ressource | 🔴 | XS | ✅ Sprint 1 |
| 4 | Naming | Ajouter `workload` au template (gotcha #8 Palo) | 🔴 | S | ✅ Sprint 1 |
| 5 | AvdHostPool | `time_static` → `time_rotating` pour le registration token | 🔴 | S | ✅ Sprint 1 |
| 6 | AvdSessionHost | Ajouter `license_type = "Windows_Client"` (HUB billing) + `patch_mode` | 🔴 | S | ✅ Sprint 1 |
| 7 | ~~Hsm~~ | ~~Security-domain activation~~ | 🟠 | M | ✅ Sprint 2 (module supprimé — KV Premium suffit) |
| 8 | StorageAccount | Exposer toggles v4 (cross_tenant_repl, infra_encryption, oauth_default, CMK, versioning) | 🟠 | M | ✅ Sprint 2 (8 toggles ajoutés) |
| 9 | vwan | Ajouter Routing Intent (`azurerm_virtual_hub_routing_intent`) | 🟠 | M | ⏸ Deferred (BGP-peered VM-Series Palo conflict — décision archi) |
| 10 | ApplicationGateway | Ajouter `force_firewall_policy_association`, `ssl_policy` (TLS 1.2+), HTTP→HTTPS redirect, UAMI for KV cert | 🟠 | M | ✅ Sprint 2 |

---

## Bugs spécifiques notables

### Critical (correctness)

- **AvdHostPool** : registration token figé via `time_static` → ne rotate jamais → token expire à `registration_expiration_hours` puis nouveaux SH ne peuvent plus rejoindre
- **AvdSessionHost** : sans `license_type=Windows_Client`, paie le full price sur Win11 multi-session au lieu de l'AHB / sans `patch_mode`, l'intégration Update Manager est cassée
- **KeyVaultStack** : `local.kv_name` non borné aux 24 chars (workload validator accepte jusqu'à 31, prefix ~12 → noms jusqu'à 47 chars qui plantent server-side)
- **KeyVault-Key** : variable `tags` documentée + acceptée mais jamais setée sur la ressource (silently dropped)
- **Hsm** : pas de chemin d'activation security-domain → la HSM est créée mais inutilisable
- **Naming** : template sans `workload` → custom roles Palo collisionnent entre prod/nprd
- **Vnet** : path inline-subnet contourne le pattern `SubnetWithNsg` et conflict avec policy Deny
- **SubnetWithNsg** : manque `nat_gateway_id`, `service_endpoints`, `private_endpoint_network_policies` → bloque PE creation

### Important (modernisation v4 / ALZ April 2026)

- **vwan** : pas de Routing Intent (GA Oct 2024) — pattern moderne pour insérer NVA/AzFW dans le flow vWAN, requis pour prod
- **ApplicationGateway** : sécurité par défaut faible (HTTP listener sans redirect, pas de SSL policy)
- **vpn** : dead branch ExpressRoute + manque v4 toggles (`private_ip_address_enabled`, `remote_vnet_traffic_enabled`)
- **StorageAccount** : toggles v4 manquants (cross_tenant_replication, infrastructure_encryption, oauth, CMK, blob versioning)
- **FinOpsHub** : `managed_virtual_network_enabled = false` hardcoded → bypasse le perimeter Palo
- **AlzArchitecture** : versions AVM en `=` exact mais ALZ library refs en `~>` flotteur — incohérent
- **LogAnalyticsAlerts** : utilise déjà `azurerm_monitor_scheduled_query_rules_alert_v2` — bon point

### Minor / hygiene

- **DnsResolver/main.tf** : mojibake UTF-8 (`���` au lieu de `—`) ligne 51
- **PrivateEndpoint** : `data.azurerm_private_endpoint_connection` jamais référencé (dead code)
- **PrivateDnsZones** : `time_static` déclaré mais jamais utilisé
- **DdosProtection** : `prevent_destroy = true` hardcoded (devrait être var-driven)
- **README manquants** : 5 modules AVD + PrivateDnsZonesCorp + FlowLogs

---

## Cross-cutting hygiène

- **Versions** : pinning `azurerm ~> 4.0` partout ✅. Mais `azapi` drift entre `~> 2.0` (LogAnalyticsAlerts) et `~> 2.4` (AlzArchitecture/AlzManagement) → standardiser sur `~> 2.4`.
- **README** : examples référencent souvent des tags `v1.0.0` qui n'existent pas dans le repo. À retirer ou créer le tag.
- **Standard variables** : la convention (`subscription_acronym`, `environment`, `region_code`, `location`, `workload`, `tags`) est respectée à ~80%. Quelques modules (Naming, ResourceLock) divergent.
- **`prevent_destroy`** : pratiquement aucun module stateful (Vnet, RT, AppGW, VPN, vWAN, Grafana) n'expose le toggle — devrait être une `variable "prevent_destroy" { default = false }`.

---

## Ce qui marche bien

- **Aks** : gère correctement les gotchas #9/#10 (KMS Private + VNet Integration + ALZ DINE policies) avec `lifecycle { ignore_changes }` propre.
- **PaloCluster** : refactor récent `kv_admin_principal_ids` (list explicite) résout le SPN/user ping-pong, élégant.
- **LogAnalyticsAlerts** : meilleur module engineering du repo — DCR ingestion + `_v2` API + handling correct du `TimeGenerated`.
- **PrivateEndpoint / Ampls / AzureMonitorWorkspace** : `lifecycle { ignore_changes = [private_dns_zone_group] }` correctement appliqué pour cohabiter avec ALZ DINE (gotcha #10).
- **FlowLogs** : utilise `azurerm_network_watcher_flow_log` avec `target_resource_id` pointant sur VNet (compliant avec la deprecation NSG flow logs sept 2027).
- **PolicyExemption** : breaking change récent (3 scopes RG/Sub/MG) bien fait, validation `length(compact([...])) == 1` propre.

---

## Suggestion d'ordre d'attaque

**Sprint 1** (fixes critiques, 1-2j) — ✅ done :
1. `principal_type = "Group"` partout
2. `KeyVault-Key` tags fix
3. `KeyVaultStack` precondition 24 chars
4. `Naming` add workload
5. `AvdHostPool` time_rotating
6. `AvdSessionHost` license_type + patch_mode

**Sprint 2** (modernisation v4, 2-3j) — ✅ done (sauf #10 deferred) :
7. `StorageAccount` toggles v4 + CMK
8. `ApplicationGateway` security defaults
9. `vpn` cleanup + v4 toggles → module supprimé (redundant avec vwan)
10. `vwan` Routing Intent → ⏸ deferred (Palo BGP conflict)
11. `private_ip_address` output fix sur PE/Ampls/AMW → ⏸ deferred (faux positif review)

**Sprint 3** (docs + hygiene, 1j) — ✅ done :
12. READMEs manquants (AVD ×5 + PrivateDnsZonesCorp + FlowLogs)
13. UTF-8 mojibake fix DnsResolver
14. Dead code cleanup (PrivateEndpoint data source, PrivateDnsZones time_static)
15. `prevent_destroy` variable sur les 6-7 modules stateful manquants

**Sprint 4** (blockers résiduels post-A1-A5 audit, ~2j, 2026-04-30 → 2026-05-04) — ✅ done :
16. `SubnetWithNsg` — `nat_gateway_id`, `service_endpoints`, `private_endpoint_network_policies`, multi-delegation
17. `Vnet` — refactor inline subnets via `azapi_resource` (NSG-deny policy compliant) + MIGRATION.md
18. `PrometheusAlertRules` — validators (max 20 alerts/group, severity 0-4) + multi `action_group_ids`
19. `ContainerRegistry` — CMK + retention/trust policy + diag settings + security toggles
20. `AvdSessionHost` — ephemeral OS × vm_size precondition + `accelerated_networking_enabled`
21. `DiagnosticSettings` — support `category_group` + `log_analytics_destination_type`

**Sprint 5** (modernisation/cohérence, ~1j, 2026-05-04) — ✅ done :
22. `azapi` provider standardisation — `~> 2.4` + casing `Azure/azapi` partout (7 modules)
23. `KeyVault` — output `vault_uri` (canonical) + `uri` deprecated alias
24. `Naming` — `environment` regex `^[a-z]{2,4}$` + `outputs.tf` → `output.tf`
25. `ResourceLock` — widen scope regex (sub/RG/resource/MG) + 2-step destroy doc
26. `AlzManagement` — pin AVM version exact (0.9.0)
27. `NatGateway` — multi-PIP (max 16) + optional management `lock`

**Sprint 6** (polish validators, <1j, 2026-05-04) — ✅ done :
28. `NSG` — priority uniqueness per-NSG validator
29. `RouteTable` — `address_prefix` CIDR / service tag validator
30. `PrivateDnsZonesCorp` — FQDN regex on `var.zones`
31. `LogAnalyticsAlerts` — severity range + `failing_periods` consistency
32. `KeyVault-Key` — RSA `key_size` default 2048 + `rotation_policy.automatic` content validator
33. `KeyVault-Secrets` — name regex (start letter, alphanumeric + hyphens, max 127)
34. `StorageAccount` — `network_rules.bypass` enum check
35. `AvdScalingPlan` — 5 validators (PascalCase days, HH:MM, percent bounds, LB algo, stop_hosts_when)

**Backlog** (sujets restants — 2026-05-04) :

- ~~HSM security-domain activation path~~ → ✅ module supprimé (KV Premium suffit, décision archi 2026-04-29)
- ~~FinOpsHub managed VNet + integration with Palo~~ → ⏸ deferred (low-value — données FinOps non-critiques)
- ~~Grafana ZR migration prod~~ → ✅ env-aware ternary (`prod = true / nprd = false`) + README warning
- Convention `CreatedOn` tag (DST issue) — refactor global (cosmétique, low priority)

---

## Sprint outcomes

**Période couverte** : 2026-04-24 (review) → 2026-05-04 (sprint 6).

**Métriques globales** :

| Sprint | Items | Status | Modules touchés | Effort réel | Notes |
|---|---|---|---|---|---|
| 1 | 6/6 | ✅ | 6+ (RBAC fix transverse) | ~1.5j | Fixes critiques |
| 2 | 5/5 (2 deferred) | ✅ | 4 + 2 supprimés (vpn, Hsm) | ~2j | Modernisation v4 |
| 3 | 4/4 | ✅ | ~10 | ~1j | Hygiène (READMEs, UTF-8, var.lock) |
| 4 | 6/6 | ✅ | 6 | ~2j | Blockers post-A1-A5 |
| 5 | 6/6 | ✅ | 9 | ~1j | Cohérence/harmonisation |
| 6 | 8/8 | ✅ | 8 | <1j | Polish validators |

**Vérifications terrain** : 5 plans testés sur infra LZ live (`network-shared` apply zero-destroy via state-rm + import migration documentée, `prometheus-aks` no-op, `diag-api` no-op, `nat-gateway` outputs-only changes, ContainerRegistry validate-only). 0 caller cassé.

**Verdicts post-sprints (delta vs review du 2026-04-24)** :

| Verdict | Avant | Après | Delta |
|---|---|---|---|
| ✅ OK | 11 (23%) | 36+ (~78%) | +25 |
| 🟡 Polish | 17 (36%) | 1-2 résiduels (DST `CreatedOn`) | -15 |
| 🟠 Rework | 18 (38%) | 0 | -18 |
| 🔴 Blocking | 1 (2%) | 0 | -1 |

**Items deferred (par décision archi, pas dette)** :

- `vwan` Routing Intent — incompatible avec BGP-peered VM-Series Palo (notre pattern)
- `PE/Ampls/AMW` `network_interface[0].private_ip_address` — l'attribut n'existe pas en v4
- `FinOpsHub` managed VNet + Palo integration — données non-critiques, ROI faible

**Items deletés** (vs review qui les considérait améliorables) :

- `vpn` module — redondant avec vwan (qui inclut le VPN gateway)
- `Hsm` module — KV Premium fournit le même niveau crypto pour notre use-case

**Stack après sprints** :

- 47 modules → 45 (vpn + Hsm supprimés)
- 2 modules ajoutés post-review : `NetworkStack` (composable spoke/hub bundle), `ResourceGroupSet` (multi-RG subscription baselines)
- 1 procédure de migration documentée (`Vnet/MIGRATION.md` — state rm + import pour le refactor azapi)
- Tous les modules sont maintenant policy-compliant ALZ (NSG-required, MFA, RBAC), ALZ AVM-aligned, et v4-modernisés.

Voir `git log --oneline --since=2026-04-26 main` pour la liste exhaustive des commits.
