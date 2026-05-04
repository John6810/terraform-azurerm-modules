# Terraform Azure Modules

Production-ready Terraform modules for Azure Landing Zone (CAF Enterprise Scale), aligned with [Azure Verified Modules (AVM)](https://azure.github.io/Azure-Verified-Modules/) patterns.

Built for [Terragrunt](https://terragrunt.gruntwork.io/) isolation but usable standalone with any Terraform workflow.

## Modules

### Core Infrastructure

| Module | Description |
|--------|-------------|
| [Vnet](./Vnet/) | Virtual Network with optional inline subnets, DDoS, and lock |
| [SubnetWithNsg](./SubnetWithNsg/) | Subnet + NSG in a single API call (azapi, for Azure Policy compliance) |
| [NSG](./NSG/) | Multiple Network Security Groups with validated rules |
| [RouteTable](./RouteTable/) | Route Table with validated routes and lock |
| [VNetPeering](./VNetPeering/) | VNet peerings (one direction per entry) |
| [NatGateway](./NatGateway/) | NAT Gateway StandardV2 (zone-redundant, azapi) |
| [DnsResolver](./DnsResolver/) | Private DNS Resolver with inbound/outbound endpoints and forwarding rules |
| [PrivateDnsZones](./PrivateDnsZones/) | All Private Link DNS Zones via AVM pattern module |
| [PrivateEndpoint](./PrivateEndpoint/) | Private Endpoints for PaaS services with DNS zone groups |
| [NetworkWatcher](./NetworkWatcher/) | Network Watcher with optional inline Resource Group |
| [DdosProtection](./DdosProtection/) | DDoS Protection Plan |

### Compute & Containers

| Module | Description |
|--------|-------------|
| [Aks](./Aks/) | Private AKS cluster (CNI Overlay, KMS v2, OIDC/WI, Defender, Prometheus) |
| [ContainerRegistry](./ContainerRegistry/) | ACR Premium with zone redundancy, RBAC, and lock |
| [ApplicationGateway](./ApplicationGateway/) | Application Gateway WAF v2 with DRS 2.1 managed rules |

### Security & Identity

| Module | Description |
|--------|-------------|
| [KeyVault](./KeyVault/) | Key Vault with RBAC, network ACLs, lock, and role assignments |
| [KeyVault-Key](./KeyVault-Key/) | Key Vault keys (RSA/EC) with rotation policies |
| [KeyVaultStack](./KeyVaultStack/) | RG + Key Vault + Private Endpoint (single deploy) |
| [Hsm](./Hsm/) | Managed HSM |
| [ManagedIdentity](./ManagedIdentity/) | User-Assigned Managed Identity with federated credentials and RBAC |
| [RbacAssignments](./RbacAssignments/) | Bulk RBAC assignments for Entra ID groups and managed identities |

### Network Security (NVA)

| Module | Description |
|--------|-------------|
| [PaloCluster](./PaloCluster/) | Palo Alto VM-Series HA cluster (ILB, CMK encryption, App Insights) |
| [vwan](./vwan/) | Virtual WAN + Hubs + VPN Sites + S2S connections (replaces the deprecated standalone `vpn` module) |

### Monitoring & Governance

| Module | Description |
|--------|-------------|
| [AzureMonitorWorkspace](./AzureMonitorWorkspace/) | Azure Monitor Workspace (Managed Prometheus) with optional PE |
| [PrometheusCollector](./PrometheusCollector/) | DCR + recording rules for AKS Prometheus metrics |
| [Grafana](./Grafana/) | Azure Managed Grafana with identity, AMW integration, and Entra RBAC |
| [ActionGroup](./ActionGroup/) | Monitor Action Group (email + push receivers) |
| [DiagnosticSettings](./DiagnosticSettings/) | Diagnostic Settings to LAW, Storage, Event Hub, or partner |
| [Ampls](./Ampls/) | Azure Monitor Private Link Scope with scoped services and PE |
| [FinOpsHub](./FinOpsHub/) | FinOps Hub (Cost Management with ADX + ADF) |

### Platform

| Module | Description |
|--------|-------------|
| [AlzArchitecture](./AlzArchitecture/) | ALZ Management Group hierarchy, policies, and Defender |
| [AlzManagement](./AlzManagement/) | ALZ Management resources (LAW, Automation Account) |
| [ResourceGroup](./ResourceGroup/) | Resource Group with lock and role assignments |
| [ResourceLock](./ResourceLock/) | Management locks (CanNotDelete / ReadOnly) on any scope |
| [StorageAccount](./StorageAccount/) | Storage Account with containers, RBAC, and lock |

## Module Patterns

All modules follow consistent patterns aligned with [AVM specifications](https://azure.github.io/Azure-Verified-Modules/):

### Naming Convention

```
{resource-prefix}-{subscription_acronym}-{environment}-{region_code}-{workload}
```

Example: `aks-api-prod-gwc-001`, `kv-mgm-prod-gwc-secrets`, `crapiprodgwc001` (ACR, no hyphens)

Every module accepts an optional `name` variable to override the computed name.

### Common Interfaces

| Interface | Pattern | Description |
|-----------|---------|-------------|
| **Collections** | `map(object)` | All iterable inputs use maps with arbitrary keys (safe at plan-time) |
| **Role assignments** | `role_definition_id_or_name` | Unified field with `strcontains()` auto-detection of ID vs name |
| **Locks** | `var.lock { kind, name }` | Optional management lock (CanNotDelete / ReadOnly) |
| **Required vars** | `nullable = false` | All required variables enforce non-null at plan-time |
| **Validations** | regex + contains | Naming vars, resource IDs, enum values validated at plan-time |
| **Outputs** | `output "resource"` | Every module exposes the complete primary resource object |
| **Tags** | `CreatedOn` auto-tag | Immutable creation timestamp via `time_static` |

### Security Defaults

| Default | Value | Modules |
|---------|-------|---------|
| Public network access | `false` | KeyVault, StorageAccount, ACR, AKS, Grafana, AMW |
| TLS version | `1.2` | StorageAccount |
| RBAC authorization | `true` | KeyVault, KeyVaultStack |
| Purge protection | `true` | KeyVault, KeyVaultStack, PaloCluster KV |
| Shared access keys | `false` | StorageAccount |
| `prevent_destroy` | `true` | KeyVault, KeyVaultStack, ACR, DDoS, StorageAccount, AKS, PaloCluster VMs/KV/Key/DES |
| PE lifecycle ignore | `[private_dns_zone_group]` | All modules with Private Endpoints (ALZ DINE policy compat) |

## Usage

### Standalone (Terraform)

```hcl
module "resource_group" {
  source = "github.com/John6810/terraform-azurerm-modules//ResourceGroup?ref=main"

  subscription_acronym = "api"
  environment          = "prod"
  region_code          = "gwc"
  workload             = "aks"
  location             = "germanywestcentral"

  lock = { kind = "CanNotDelete" }

  role_assignments = {
    aks_contributor = {
      role_definition_id_or_name = "Contributor"
      principal_id               = "00000000-0000-0000-0000-000000000000"
    }
  }

  tags = { Environment = "Production" }
}
```

### With Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/ResourceGroup"
}

inputs = {
  subscription_acronym = include.sub.locals.subscription_acronym
  environment          = include.root.inputs.environment
  region_code          = include.root.inputs.region_code
  workload             = "aks"
  location             = include.root.inputs.location
  lock                 = { kind = "CanNotDelete" }
  tags                 = include.root.inputs.common_tags
}
```

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.5.0 |
| azurerm | ~> 4.0 |
| azapi | ~> 2.0 (SubnetWithNsg, NatGateway) |
| azuread | ~> 3.0 (RbacAssignments) |
| time | >= 0.9.0 |

## License

This project is licensed under the MPL-2.0 License - see the [LICENSE](LICENSE) file for details.
