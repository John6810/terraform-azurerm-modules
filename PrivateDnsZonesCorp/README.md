# PrivateDnsZonesCorp

Deploys a **dedicated Resource Group** + a configurable list of **corporate-internal Azure Private DNS zones** (e.g. `az.epttst.lu`, `corp.example.com`) and links them to a set of VNets for resolution. Companion to the `PrivateDnsZones` module which handles the standard `privatelink.*` zones from the ALZ AVM library.

## Usage

### Standalone

```hcl
module "corp_dns_zones" {
  source = "github.com/John6810/terraform-azurerm-modules//PrivateDnsZonesCorp?ref=PrivateDnsZonesCorp/v1.0.0"

  subscription_acronym = "con"
  environment          = "nprd"
  region_code          = "gwc"
  location             = "germanywestcentral"

  zones = [
    "az.epttst.lu",
    "corp.example.com",
  ]

  virtual_network_links = {
    nva = {
      virtual_network_id   = "/subscriptions/.../virtualNetworks/vnet-con-nprd-gwc-nva"
      registration_enabled = false
    }
    shared = {
      virtual_network_id   = "/subscriptions/.../virtualNetworks/vnet-con-nprd-gwc-shared"
      registration_enabled = false
    }
  }

  tags = { Environment = "Non Production" }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/PrivateDnsZonesCorp"
}

dependency "vnet_nva"    { config_path = "../network-shared" }
dependency "vnet_shared" { config_path = "../network-shared" }

inputs = {
  subscription_acronym = include.sub.locals.subscription_acronym
  environment          = include.root.inputs.environment
  region_code          = include.root.inputs.region_code
  location             = include.root.inputs.location

  zones = ["az.epttst.lu"]

  virtual_network_links = {
    nva    = { virtual_network_id = dependency.vnet_nva.outputs.id,    registration_enabled = false }
    shared = { virtual_network_id = dependency.vnet_shared.outputs.id, registration_enabled = false }
  }

  tags = include.root.inputs.common_tags
}
```

## Naming Convention

| Resource | Pattern |
|---|---|
| Resource Group | `rg-{subscription_acronym}-{environment}-{region_code}-dns-zones` |
| VNet link | `link-{vnet_key}-{zone_dotless}` |

## Required Inputs

| Name | Type | Description |
|---|---|---|
| `subscription_acronym` / `environment` / `region_code` | `string` | Naming convention components |
| `location` | `string` | Azure region (the RG location — Private DNS zones themselves are global) |
| `zones` | `list(string)` | FQDN list of corp zones to create |
| `virtual_network_links` | `map(object)` | Map of VNet key → `{virtual_network_id, registration_enabled}` |

## Outputs

- `resource_group_name` — RG hosting the corp zones
- `resource_group_id` — RG resource ID
- `zone_ids` — Map zone FQDN → Private DNS zone resource ID (for use by Private Endpoints' `private_dns_zone_group`)

## Notes

- **Scope distinction**: this module is for **corp-internal** zones (custom-named domains). For the standard Azure Private Link zones (`privatelink.vaultcore.azure.net`, `privatelink.blob.core.windows.net`, …) use the `PrivateDnsZones` module which wraps `Azure/avm-ptn-network-private-link-private-dns-zones/azurerm`.
- **VNet links**: pass each VNet that should resolve these zones. Set `registration_enabled = true` on at most ONE link per zone if you want VMs to auto-register their hostnames (rare for corp zones).
- **Cross-sub linking**: if the consuming VNets live in a different subscription than the zones, the deployer needs `Private DNS Zone Contributor` on the zone RG.
