# Review terraform-azurerm-modules — Synthèse

**Date** : 2026-04-24 — **Modules** : 47 — **Provider baseline** : azurerm v4.x (2026-04)

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

### 1. 🔴 `principal_type = "Group"` manquant sur role assignments

Le bug fixé dans le commit `da4e610` (rbac-avd) **n'a pas été propagé** aux autres modules :

- `RbacAssignments` — block `groups` sans `principal_type` → `UnmatchedPrincipalType`
- `Grafana` — 3 blocks RBAC + identity sans `principal_type`
- `ManagedIdentity` — sans `principal_type` sur les outputs/role assignments si exposés
- 5 modules AVD — pas encore complété

**Fix** : ajouter `principal_type = "Group"` partout où on assigne un rôle à un groupe AAD. `ContainerRegistry` peut servir de template (déjà conforme).

### 2. 🟠 `private_ip_address` lu depuis `private_service_connection[0]` au lieu du NIC

Sous azurerm v4, `private_service_connection[0].private_ip_address` est souvent vide. Touche :

- `PrivateEndpoint`
- `Ampls`
- `AzureMonitorWorkspace`

**Fix** : `output "private_ip" { value = azurerm_private_endpoint.this.network_interface[0].private_ip_address }`

### 3. 🟡 Pattern `time_static + timeadd("1h")` pour `CreatedOn` tag

Tous les modules ajoutent +1h au timestamp UTC pour simuler CET. Ne marche pas en hiver (DST). Touche pratiquement tous les modules. **Fix** : utiliser `timestamp()` formaté avec l'offset depuis une variable, ou simplement laisser UTC.

### 4. 🟠 Outputs naming drift

- `KeyVault` expose `uri` au lieu de `vault_uri` (incohérent avec `azurerm_key_vault.vault_uri`)
- `vpn` expose `vpn_gateway_id` / `vpn_gateway_name` au lieu de `id` / `name`

**Fix** : standardiser sur `id`, `name`, `<resource>_<property>`.

---

## Top 10 actions prioritaires

| # | Module | Action | Sévérité | Effort |
|---|---|---|---|---|
| 1 | RbacAssignments + Grafana + ManagedIdentity + AVD×5 | Ajouter `principal_type = "Group"` partout | 🔴 | S |
| 2 | KeyVaultStack | Ajouter precondition sur 24-char KV name limit | 🔴 | S |
| 3 | KeyVault-Key | Fix bug `tags` jamais appliqué sur la ressource | 🔴 | XS |
| 4 | Naming | Ajouter `workload` au template (gotcha #8 Palo) | 🔴 | S |
| 5 | AvdHostPool | `time_static` → `time_rotating` pour le registration token | 🔴 | S |
| 6 | AvdSessionHost | Ajouter `license_type = "Windows_Client"` (HUB billing) + `patch_mode` | 🔴 | S |
| 7 | Hsm | Documenter security-domain activation manuelle (hors TF) ou ajouter azapi | 🟠 | M |
| 8 | StorageAccount | Exposer toggles v4 (cross_tenant_repl, infra_encryption, oauth_default, CMK, versioning) | 🟠 | M |
| 9 | vwan | Ajouter Routing Intent (`azurerm_virtual_hub_routing_intent`) | 🟠 | M |
| 10 | ApplicationGateway | Ajouter `force_firewall_policy_association`, `ssl_policy` (TLS 1.2+), HTTP→HTTPS redirect, UAMI for KV cert | 🟠 | M |

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

**Sprint 1** (fixes critiques, 1-2j) :
1. `principal_type = "Group"` partout
2. `KeyVault-Key` tags fix
3. `KeyVaultStack` precondition 24 chars
4. `Naming` add workload
5. `AvdHostPool` time_rotating
6. `AvdSessionHost` license_type + patch_mode

**Sprint 2** (modernisation v4, 2-3j) :
7. `StorageAccount` toggles v4 + CMK
8. `ApplicationGateway` security defaults
9. `vpn` cleanup + v4 toggles
10. `vwan` Routing Intent
11. `private_ip_address` output fix sur PE/Ampls/AMW

**Sprint 3** (docs + hygiene, 1j) :
12. READMEs manquants (AVD ×5 + PrivateDnsZonesCorp + FlowLogs)
13. UTF-8 mojibake fix DnsResolver
14. Dead code cleanup (PrivateEndpoint data source, PrivateDnsZones time_static)
15. `prevent_destroy` variable sur les 6-7 modules stateful manquants

**Backlog** (sujets plus lourds) :
- HSM security-domain activation path (dépend de la stratégie HSM globale)
- FinOpsHub managed VNet + integration with Palo
- Grafana ZR migration prod (immutable, requires recreation)
- Convention `CreatedOn` tag (DST issue) — refactor global
