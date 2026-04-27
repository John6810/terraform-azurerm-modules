# NetworkStack

Generic regional spoke (or hub) network bundle: RG + Network Watcher + vnet +
Route Table + NSGs + Subnets, in a single Terraform/Terragrunt apply.

Replaces the 5-6 separate deployments pattern (`network-watcher`, `network-{wl}`,
`nsg-{wl}`, `rt-{wl}`, `subnet-{wl}`) with one composed module. Designed to
host any workload — AVD, AKS, App Service, Bastion, NetApp, generic VMs,
dedicated PE subnets, or any combination thereof.

## What it builds

- (optional) `rg-{prefix}-network`
- (optional) `nw-{prefix}-network` (Network Watcher)
- `vnet-{prefix}-{workload}` with custom DNS, DDoS Standard, encryption (opt-in)
- `rt-{prefix}-{workload}` with default route → NVA, BGP propagation off
- `nsg-{prefix}-{subnet_key}` per subnet (create_nsg=true)
- subnets via `azapi_resource` (1-shot PUT with NSG + RT — satisfies
  `Deny-Subnet-Without-Nsg` policy)

## Prerequisites

- Terraform ≥ 1.5
- Provider `hashicorp/azurerm ~> 4.0`
- Provider `Azure/azapi ~> 2.0`
- Provider `hashicorp/time >= 0.9.0`

## Usage examples

### AVD spoke (4 subnets — session hosts + PEs)

```hcl
module "network_avd" {
  source = "../../modules/NetworkStack"

  subscription_acronym = "avd"
  environment          = "nprd"
  region_code          = "gwc"
  workload             = "spoke"

  location           = "germanywestcentral"
  vnet_address_space = ["10.239.5.0/24"]

  dns_servers               = ["10.239.200.36"]   # Palo ILB / DNS proxy
  ddos_protection_plan_id   = "/subscriptions/.../ddosProtectionPlans/ddos-shared"
  default_route_next_hop_ip = "10.239.200.36"     # default 0.0.0.0/0 → Palo ILB

  subnets = {
    hosts = {
      cidr = "10.239.5.0/26"
    }
    "pe-avd" = {
      cidr                              = "10.239.5.64/28"
      private_endpoint_network_policies = "Disabled"
    }
    "pe-storage" = {
      cidr                              = "10.239.5.80/28"
      private_endpoint_network_policies = "Disabled"
    }
    "pe-kv" = {
      cidr                              = "10.239.5.96/28"
      private_endpoint_network_policies = "Disabled"
    }
  }

  tags = { Workload = "avd" }
}
```

### AKS spoke (with API server delegation)

```hcl
module "network_aks" {
  source = "../../modules/NetworkStack"

  subscription_acronym = "api"
  environment          = "prod"
  region_code          = "gwc"
  workload             = "spoke"

  location                  = "germanywestcentral"
  vnet_address_space        = ["10.238.0.0/24"]
  dns_servers               = ["10.238.200.36"]
  ddos_protection_plan_id   = local.ddos_id
  default_route_next_hop_ip = "10.238.200.36"

  subnets = {
    nodes = {
      cidr = "10.238.0.128/26"
    }
    pods = {
      cidr = "10.238.0.64/28"
    }
    apiserver = {
      cidr = "10.238.0.32/28"
      delegation = {
        name         = "aks-apiserver"
        service_name = "Microsoft.ContainerService/managedClusters"
      }
    }
    storages = {
      cidr                              = "10.238.0.48/28"
      private_endpoint_network_policies = "Disabled"
    }
  }
}
```

### Hub vnet with shared services + Bastion

```hcl
module "network_hub" {
  source = "../../modules/NetworkStack"

  subscription_acronym = "con"
  environment          = "prod"
  region_code          = "gwc"
  workload             = "shared"

  location           = "germanywestcentral"
  vnet_address_space = ["10.238.204.0/23"]

  # Hub doesn't route through itself
  create_route_table = false

  subnets = {
    AzureBastionSubnet = {
      name = "AzureBastionSubnet"
      cidr = "10.238.204.0/26"
      # Bastion supports custom NSG with specific rules; keep create_nsg=true
      # but populate nsg_rules per the Bastion documentation.
    }
    "dns-in" = {
      cidr               = "10.238.204.64/28"
      attach_route_table = false
      delegation = {
        name         = "Microsoft.Network.dnsResolvers"
        service_name = "Microsoft.Network/dnsResolvers"
      }
    }
    "dns-out" = {
      cidr               = "10.238.204.80/28"
      attach_route_table = false
      delegation = {
        name         = "Microsoft.Network.dnsResolvers"
        service_name = "Microsoft.Network/dnsResolvers"
      }
    }
  }
}
```

### Special-case subnets

| Subnet name | Settings |
|---|---|
| `AzureBastionSubnet` | `create_nsg = true` with Bastion rules; `attach_route_table = false` (routes per design) |
| `GatewaySubnet` | `create_nsg = false` (Azure forbids); `attach_route_table = false` |
| `AzureFirewallSubnet` | `create_nsg = false` (Azure forbids); `attach_route_table = false` |
| `AzureFirewallManagementSubnet` | `create_nsg = false`; `attach_route_table = false` |

## Outputs

| Output | Description |
|---|---|
| `vnet_id`, `vnet_name`, `vnet_address_space` | vnet identifiers |
| `subnet_ids`, `subnet_names` | maps keyed by the subnet identifier you used in the input |
| `nsg_ids`, `nsg_names` | NSG maps (only for subnets with create_nsg=true) |
| `route_table_id`, `route_table_name` | RT identifiers (null if not created) |
| `network_watcher_id`, `network_watcher_name` | NW identifiers (null if not created) |
| `resource_group_name`, `resource_group_id` | RG identifiers (created or existing) |

## Best practices baked in

- **NSG required by default** on every subnet (ALZ `Deny-Subnet-Without-Nsg`)
- **NSG attached at create time** (azapi 1-shot PUT)
- **BGP propagation OFF** on the route table (UDRs win deterministically)
- **`defaultOutboundAccess = false`** on all subnets (future-proof for Microsoft's
  Sept 2025 retirement of default outbound access)
- **DDoS Standard** referenceable via `ddos_protection_plan_id` (recommended for
  prod-facing spokes)
- **Custom DNS** wired to the NVA / DNS resolver IP for hub-and-spoke models
- **`encryption.enforcement`** opt-in for east-west encrypted-only enforcement
- **flow_timeout_in_minutes** opt-in for long-running connections (default 4 min
  Azure timeout can break long-poll patterns)

## What's deliberately not in scope

- **VNet peerings** — separate deployment that consumes outputs from N
  NetworkStack instances. Bundling creates chicken-and-egg between paired stacks.
- **Private Endpoints** — workload-specific lifecycle, deployed alongside the
  PaaS resource they front (Storage, KV, AVD, etc.).
- **Flow logs** — typically lives cross-sub (storage in connectivity hub) +
  optional traffic analytics integration. Use the `FlowLogs` module separately.
- **DNS resolver / Private DNS zones** — connectivity sub concerns, not spoke.
