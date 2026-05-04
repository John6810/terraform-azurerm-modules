# Post-Sprint Architectural Audit — Sprint 7 scope

**Date** : 2026-05-04
**Auteur** : Plan architect agent (read-only review)
**Périmètre** : Le repo après les Sprints 1-6 (cf. `REVIEW/INDEX.md` pour l'état initial)

> Cette revue est **distincte** de l'audit du 2026-04-24 : elle prend une lentille structurelle (composition, boundaries, gaps, drift cross-cutting) plutôt qu'un checklist par module. Elle catalogue ce que l'audit initial a manqué.

---

## Sprint 7 progress — 2026-05-04

| Item | Décision | Commit |
| --- | --- | --- |
| **P0 #1 Composition strategy** | ✅ Décidé : **Option (c)** — accept duplication + CI lint à venir. L'audit du drift réel (KeyVault canonical vs KeyVaultStack inline) a montré un écart de seulement 4 lignes intentionnelles. Refactor `git::` impose state migrations sur 100 % des callers (KeyVaultStack → `module.kv.azurerm_key_vault.this`) pour un gain marginal. | (décision documentée ici) |
| **P0 #4 Naming dead module** | ✅ **Killed** — 0 caller vérifié dans LZ. Voir note "Naming convention reintroduction" ci-dessous pour l'opportunité future. | `chore/sprint7-kill-naming-and-vpn` |
| **#4 Variable-ize `prevent_destroy`** | ❌ **Infeasible** — Terraform 1.5 refuse `prevent_destroy = var.prevent_destroy` avec l'erreur explicite `Variables may not be used here. Unsuitable value: value must be known`. La contrainte est hard : `lifecycle.prevent_destroy` doit être un literal au moment du graph build (avant résolution des variables). L'audit du Plan agent s'est trompé sur la faisabilité. **Alternative**: utiliser `var.lock` (Azure-side `azurerm_management_lock`, déjà variable-driven sur 17 modules) qui offre la même protection au niveau Azure et survit aux pertes de state. Pour les 9 occurrences de `prevent_destroy = true` hardcodé restantes (KeyVault, KeyVaultStack, ContainerRegistry, Aks, DdosProtection, PaloCluster KV/Key/DES/VM-Series), le statu quo s'impose. Pour destroy un caller, workflow nécessaire : `terraform state rm <resource>` puis apply, OU fork le module. | (constat documenté ; pas de commit) |
| **P2 vpn/ leftover dir** | ✅ **Removed** — directory disque vestigial post-Sprint 2. | idem |
| **P2 ResourceLock à kill** | ❌ **Annulé** : 2 callers actifs (`locks-api`, `locks-avd`) utilisent le pattern map-based bulk-lock — use case unique vs `var.lock` inline. L'audit s'était trompé. | — |

### Naming convention — opportunité de réintroduction

La suppression du module `Naming` n'est **pas** une renonciation à la centralisation du naming. Le statu quo actuel :

- **Pattern dupliqué 44 ×** dans chaque module : `locals { computed_name = "{prefix}-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.workload}" }`
- **Validators dupliqués 44 ×** sur les inputs (regex `^[a-z]{2,5}$` pour acronym, `^[a-z]{2,4}$` pour env, etc.)
- Convention documentée dans `CONTRIBUTING.md` ("Naming logic")

C'est exactement la duplication flaggée en P1 #1 (role_assignments shape) et P1 #8 (validators) du présent audit — mais transposée au naming. Le module `Naming` qu'on vient de tuer **aurait pu** être la source de vérité unique, mais il n'avait pas été adopté (il enveloppait `Azure/naming/azurerm` + types Palo custom, jamais wired par le LZ).

**Réintroduction future possible** (Sprint dédié, ~3-5 jours) :

1. Recréer un module `Naming` minimaliste (locals + validators canoniques, pas de wrapper Azure/naming officiel)
2. Migrer les 44 modules pour le consommer (`module "naming" { source = "../Naming" ... }` — mais cf. P0 #1 `git::` vs duplication, applicable ici aussi)
3. State migration : les resources sont déjà nommées d'après le pattern, donc 0 destroy/recreate côté Azure — uniquement re-render des `local.name` côté Terraform

**Conditions de déclenchement** suggérées :

- Une nouvelle convention de naming est imposée (ex: ajout segment `pillar` ou changement de séparateur)
- Une nouvelle env (ex: `dr` ou `sandbox`) ne match pas le regex `^[a-z]{2,4}$` actuel
- Un audit interne identifie un module qui a dérivé du pattern (validation manuelle requise)

Tant qu'aucune de ces conditions n'est rencontrée, **la duplication 44 × est acceptée comme dette consciente** — coût de maintenance minime tant que la convention reste stable, refactor possible en 1 sprint dédié quand le besoin émerge.

---

## 🔴 P0 — Strategic issues (design-level)

| # | Module(s) / Area | Issue | Why it matters | Effort / Impact |
| --- | --- | --- | --- | --- |
| 1 | `KeyVaultStack`, `PaloCluster/diskencryption.tf`, `NetworkStack`, `ResourceGroupSet` | Les 4 modules réimplémentent verbatim la logique de leurs child modules ("Terragrunt only copies the module folder into its cache" — commentaire explicite dans les 4 fichiers). `azurerm_key_vault`, `azurerm_resource_group`, `azurerm_role_assignment`, `azurerm_management_lock`, `azurerm_private_endpoint`, `azurerm_user_assigned_identity` existent en 4-13 copies. | Chaque fix sur les patterns KV/RG/PE/RBAC doit être appliqué N+1 fois. Sprint 1-6 a déjà raté de propager `vault_uri`, `lock`, validators, `principal_type` aux copies inline (PaloCluster/KV par exemple). Drift baked-in. | M-L : extraire un partial `_shared/` Terragrunt OU migrer les orchestrateurs vers des sources `git::` cross-référencées OU accepter la duplication + CI lint qui diff-check les blocs inline contre les modules canoniques. |
| 2 | `vwan` | God-module : VWAN core + hubs + ER/VPN/P2S gateways + VPN configs + sites + connections + BGP — 6 surfaces conceptuelles, ~750 lignes, namespace var flat. Routing Intent deferred faute de conflit avec une sub-feature. | Toute addition future (Routing Intent, secured hub, scenario opcode) compose le blast radius. Single state porte le risque de destruction du hub prod. | M : split en `Vwan` (core) + `VwanHub` + `VwanGateway` (S2S/P2S/ER) + `VwanRouting`. Migration via `moved {}` blocks. |
| 3 | `Aks` | Le module ne livre PAS un cluster fonctionnel tout seul — KMS v2 + API server VNet integration doivent être activés out-of-band via `az aks update` (commenté dans `main.tf:236`). `lifecycle ignore_changes` cache l'état post-deploy à Terraform. | Nouvelle env nécessite runbook humain ; drift detection cassée sur `api_server_access_profile` & `key_management_service`. | L : track issue azurerm provider #27640, revisit quand v4 fix landed ; en attendant ajouter `null_resource { local-exec = az aks update … }` gated par flag pour rendre le module self-contained. |
| 4 | `Naming` module | **Zero usage** dans le LZ (vérifié : aucun `module "naming"` ou `source = ".../Naming"`). Tous les 81 leaves utilisent des inline strings `"kv-${prefix}-${workload}"`. Le module existe avec validators étendus + types Palo custom mais est mort. | Coût de maintenance sans payoff ; risque de drift entre Naming module template et inline strings (Sprint 1 a ajouté `workload` au template, mais inline strings l'avaient déjà). | S : soit DELETE Naming, soit MANDATER (refactor 81 leaves pour l'appeler). Le statu quo "schrödinger module" est le pire des cas. |
| 5 | Pas de pattern composition pour : KV-with-PE (shc/avd/api), AKS-bundle (RG + IDs + KV + Key + RBAC + AKS), AVD-bundle (5 modules), Monitoring-bundle | `KeyVaultStack` est le seul "*Stack" historique ; `NetworkStack` vient d'arriver. Pas de `AksStack`, `WorkloadIdentityStack` (RG+IDs+RBAC), `MonitoringStack` (LAW+AMW+Grafana+ActionGroup) malgré des structures évidemment répétées sur les 5 nprd subs. | LZ duplique 5× les mêmes wirings IDs/RBAC/diag par workload. Doubler les subs double le boilerplate. | M : répliquer le pattern orchestrateur (après que l'issue 1 soit résolue). |
| 6 | `LogAnalyticsAlerts` mal classé | Le module est *alert rules* — mais le LZ a aussi `ActionGroup`, `PrometheusAlertRules`, le bundle AMBA dans `AlzManagement`, `Ampls`, `azuremonitorworkspace` — pipeline d'alerting = 5 modules avec recouvrements et **pas de seam clair** entre alertes Defender (AlzManagement), AMBA (AlzManagement aussi), AKS (PrometheusAlertRules), platform (LogAnalyticsAlerts), action delivery (ActionGroup). | Onboarding new workload alerts demande connaissance cross-module. Routing cross-module (quelle alerte fire sur quel AG) est implicite. | M : documenter la topologie alerting dans `REVIEW/MONITORING-TOPOLOGY.md` d'abord ; puis décider si un `MonitoringStack` est justifié. |

---

## 🟠 P1 — Cross-cutting drift (consistency)

| # | Pattern | Modules affectés | Recommandation |
| --- | --- | --- | --- |
| 1 | `role_assignments` shape : full 8-field (`condition`, `condition_version`, `description`, `skip_*_aad_check`, `delegated_*`) vs **abrégé** | StorageAccount, ContainerRegistry, ManagedIdentity, KeyVaultStack, ResourceGroupSet, ResourceGroup vs `Grafana` (`identity_role_assignments` = scope+role only), `KeyVault` (none), Vnet/RT/NatGateway/NSG (no role_assignments at all), `RbacAssignments` split en `group_assignments`/`identity_assignments` | Définir un `_shared/role_assignment.tf.tpl` ; pick une shape canonique 8-field et appliquer uniformément. KeyVault devrait le supporter ; Grafana devrait s'étendre. |
| 2 | Output naming : `id` / `name` / `vault_uri` (KeyVault) vs `key_vault_id` / `key_vault_name` / `key_vault_uri` (KeyVaultStack) — même resource, prefixé en stack | KeyVaultStack, NetworkStack, ResourceGroupSet, KeyVault | Dans les stacks, exposer les deux (un-prefixed pour delegation + prefixed pour disambiguation), OU pick une règle et appliquer cross-stacks. |
| 3 | Diagnostic settings : inline (Aks, ContainerRegistry) vs module séparé `DiagnosticSettings` (le reste, 9+ leaves) | Aks (inline), ContainerRegistry (inline), 9+ leaves use module | Inline le diag setting dans chaque module qui crée une "primary resource" pour que le caller n'ait pas à wirer `diag-foo` séparément. La bifurcation actuelle est le pire cas (caller ne sait pas si diag est déjà set). |
| 4 | `lock` variable shape `object({ kind, name? })` vs ResourceLock module standalone `locks = map(...)` | 17 modules avec inline lock + 1 standalone ResourceLock | Deprecate ResourceLock — désormais redondant pour tout sauf scenarios bulk-lock cross-resource (non utilisés en LZ). |
| 5 | `customer_managed_key` + `identity_ids` merge dance | StorageAccount (lines 22-23), ContainerRegistry — même pattern en 2 places, va se propager | Extraire en sub-pattern documenté (locals fragment + var shape) à copier verbatim ; éventuellement shared module. |
| 6 | `tags = merge(var.tags, { CreatedOn = formatdate(... timeadd(time_static.time.id, "1h")) })` | 35 modules — même logique fausse en hiver (DST) | Soit (a) strip tag globalement (1-line × 35), soit (b) move `time_static + formatdate` dans un partial `locals.tf` partagé, soit (c) caller responsibility. Backlog item du review original toujours ouvert. |
| 7 | `azapi` provider version | Tous les modules utilisant azapi | Add CI check `grep -r "azapi" -A2 version.tf` pour enforcer pin identique. |
| 8 | Validators subscription/region/workload dupliqués dans chaque variables.tf avec variations subtiles | All modules | Centraliser via `_validation` partial OU accepter duplication + unit test qui asserte regex strings identiques. |

---

## 🟡 P1 — Gap analysis (missing modules)

| Resource type | Used in LZ at | Suggested module name |
| --- | --- | --- |
| `azurerm_application_insights` | inline in `PaloCluster` (1 use); future for ApiSix/AKS workloads | **ApplicationInsights** (workspace-based, role_assignments, diag) |
| `azurerm_monitor_metric_alert` | not yet — but 5 nprd + AVD + APIM auront besoin de cost/availability metric alerts | **MetricAlert** (ou expand `LogAnalyticsAlerts`) |
| `azurerm_recovery_services_vault` + `azurerm_backup_*` | not deployed — SHC/AVD personal hosts auront besoin Azure Backup | **RecoveryVault** |
| `azurerm_bastion_host` | not deployed — pattern jump access via Palo VPN ; document deferred ou build module si Bastion remplace VPN ops | **Bastion** (defer si vpn-only by policy) |
| `azurerm_storage_container` / `azurerm_storage_share` standalone | inline dans `StorageAccount` only — impossible d'add containers à existing SA | **StorageContainer** / **StorageShare** |
| `azurerm_role_definition` (custom roles) | inline dans `PaloCluster` only (`PAN-OS AppInsights`) | **CustomRoleDefinition** (réutilisable pour AKS, Grafana scopes) |
| `azurerm_user_assigned_identity` "stack" | LZ a `id-aks-cp`, `id-aks-kubelet`, `sp-avd` — chaque un leaf séparé avec full RBAC | **WorkloadIdentitySet** (multi-identity bundle) |
| `azurerm_log_analytics_workspace` | uniquement embedded dans `AlzManagement` — pas de standalone pour workload-LAWs | **LogAnalyticsWorkspace** (si workload veut son propre) |
| `azurerm_monitor_data_collection_rule` (DCR) | LogAnalyticsAlerts utilise inline ; ALZ Policy crée MSCI ; AKS Container Insights crée le sien | **DataCollectionRule** (centralise transform-KQL pattern) |
| `azurerm_dns_zone` (public) | not deployed (corp-only via PrivateDnsZones[Corp]) | defer |

---

## 🟢 P2 — Tech debt (future cleanup)

- `KeyVault.uri` output deprecated since Sprint 5 — set v2 cut date (e.g. Sprint 9) and remove. Sits forever sinon.
- `vpn/` directory existe encore dans le repo (only `.terraform/` cache) malgré la suppression Sprint 2 — `git rm -rf vpn/`.
- 13 modules dupliquent `azurerm_resource_group` creation sans toggle `var.create_resource_group` (NetworkStack OK, autres NOT).
- `time_static` resource dans 35 modules jamais lu post-creation — keeps state-bloat. Si `CreatedOn` killed, drop `time` provider de 35 version.tf.
- `RbacAssignments` split en `group_assignments` (resolves by display_name) + `identity_assignments` (by object_id) — mais inline `role_assignments` dans la plupart des modules ne supporte que object_id. Inconsistency.
- `ResourceLock` standalone redundant avec `var.lock` × 17 modules — deprecate ou doc bulk-lock use case.
- `Naming/QUICK_REFERENCE.md` existe mais module unused — remove docs ou use module.
- `ContainerRegistry` et `ApplicationGateway` modules ont **0 consumer** dans le LZ — soit add APIM/ACR workload, soit mark "available, no caller" en README.
- `KeyVaultStack/main.tf:180-185` — `data "azurerm_private_endpoint_connection"` dead lookup (déjà fixé dans `PrivateEndpoint`, oublié ici).
- `prevent_destroy = true` hardcoded sur KeyVault, KeyVaultStack, ContainerRegistry, AKS, PaloCluster KV/Key/DES — review original a flaggé DDoS only ; même fix needed elsewhere.
- 5 modules AVD totalisant 1263 lignes pour un workload domain unique — candidat pour `AvdStack`.
- `LESSONS-LEARNED.md` et `BACKLOG.md` existent dans `landing-zone/corporate/avd/` — utiles, mais pas d'équivalent pour autres workloads. Standardize per-workload doc set.

---

## 🪞 Critique de la review originale (2026-04-24)

Ce qu'elle a raté :

- **Aucune lentille structurelle** — checklist 47 modules avec verdicts OK/Polish/Rework/Blocking, **zéro** analyse de boundaries / duplications / orchestrateurs manquants. Le pattern "fake child module" (KeyVaultStack, PaloCluster/diskencryption, NetworkStack, ResourceGroupSet — qui carry tous le commentaire "cannot delegate because Terragrunt cache") est la **single most expensive design constraint** du repo, **jamais mentionné**.
- **Aucun gap analysis** — review check ce qui existe ; jamais demandé "qu'est-ce qui manque ?". AppInsights, MetricAlert, Backup, CustomRole sont gaps évidents sur un grep de `landing-zone/`.
- **Aucun usage check** — Naming est unused ; ContainerRegistry/AppGW sont available-but-uncalled. Reviewer accepte le module "OK" sans check du call graph.
- **role_assignments shape drift raté** — review a flaggé `principal_type = "Group"` (un field), mais pas la shape complète 8-field. ManagedIdentity/SA/ACR/KVStack/RGSet/RG la portent ; KV/Grafana/RbacAssignments/identity_assignments ont versions abrégées/différentes. Sprint 1 n'a pas adressé la question broader.
- **Convention output naming pas analysée** — `id`/`name` vs `<resource>_id`/`<resource>_name` inconsistent entre standalone (KeyVault) et stack modules (KeyVaultStack). Le rename `uri` mentionné, broader policy ratée.
- **Inline diag pattern (ContainerRegistry, Aks) vs DiagnosticSettings module pas flaggé comme décision archi** — repo porte les 2 simultanément ; callers ne savent pas lequel est canonique.
- **CreatedOn tag merge** — identifié une fois "DST issue, low priority cosmetic" mais c'est l'exemple canonique de **uncentralized cross-cutting concern** dupliqué 35×. Le fix n'est pas cosmétique, c'est une maintainability liability.
- **prevent_destroy** — Sprint 3 a ajouté `var.lock` mais jamais variable-isé `prevent_destroy` sur KV, ACR, AKS — le gap analysis review était incomplet là-dessus.
- **Tests/CI** — review a checké "renovate.json exists" mais jamais demandé si modules ont **un seul** unit test (`tftest.hcl`). Réponse : zéro. CI = `terraform validate` only. Pour 45-module library, **glaring blind spot**.
- **Pas de discussion de l'orchestrator anti-pattern** — NetworkStack et ResourceGroupSet "added in Sprints 1-6" mais la décision archi d'introduire des `*Stack` patterns n'est documentée nulle part. Future maintainers won't know when to add another *Stack vs. extend a primitive.

---

## 🎯 Sprint 7 recommandé (~5 jours)

1. **Décision : composition strategy** (1j, **bloque #2-5**) — résoudre le blocker "Terragrunt cache breaks child modules" : (a) `git::` source URLs entre orchestrators et siblings, (b) extract `_shared/` partial que tous les modules duplicants `include` via Terragrunt `read_terragrunt_config`, ou (c) accept duplication + `make lint-duplication` CI check qui diff inline KV/PE/RG blocks vs canonical. **Pick one explicitly** et documenter dans `CONTRIBUTING.md`.
2. **role_assignments + outputs canonicalisation** (1j) — une shape canonique 8-field. Apply à KeyVault, Grafana, ManagedIdentity. Standardize stack output convention (`<resource>_id` en stacks, `id` en primitives). MIGRATION.md per module touched.
3. **Kill or use** (0.5j) — Naming, ResourceLock, `vpn/` leftover. Trois explicit deletes ou trois explicit adoptions. Plus de schrödinger modules.
4. **Variable-ize `prevent_destroy`** (0.5j) sur stateful modules manquants (KV, KVStack, ACR, AKS, PaloCluster KV/Key/DES, Vnet, RT, AppGW, vWAN, Grafana). Default `true` pour KV/Key/AKS/DES ; default `false` ailleurs. Sprint 3 ne l'a fait qu'à moitié.
5. **Add unit-test scaffold** (1.5j) — `tftest.hcl` pour les 8 modules les plus utilisés (KV, KVStack, NetworkStack, RG, RGSet, StorageAccount, RbacAssignments, DiagnosticSettings) — au minimum plan-level tests avec mock providers. CI matrix on PR. Foundation pour future refactors.

---

## Critical Files for Implementation

- [KeyVaultStack/main.tf](../KeyVaultStack/main.tf)
- [PaloCluster/diskencryption.tf](../PaloCluster/diskencryption.tf)
- [NetworkStack/main.tf](../NetworkStack/main.tf)
- [Naming/main.tf](../Naming/main.tf)
- `.github/workflows/ci-modules.yml` (à créer)

---

## Verdict global

La review du 2026-04-24 était une **revue de surface** : excellente sur les bugs concrets (35 items résolus en Sprints 1-6), faible sur l'architecture. Le repo est maintenant dans un état "polished v1" stable, mais **6 issues structurelles P0** restent — surtout le pattern "fake child module" qui est la vraie dette de fond. Sprint 7 est l'opportunité de passer d'un repo qui *fonctionne* à un repo qui *compose et scale*.
