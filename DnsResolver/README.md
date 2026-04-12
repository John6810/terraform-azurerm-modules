# DnsResolver

Deploys an Azure DNS Private Resolver with its own resource group, an inbound endpoint (receives DNS queries from VNets/Palo), an optional outbound endpoint, and optional DNS forwarding rules with VNet links.

## Usage

### Standalone

```hcl
module "dns_resolver" {
  source = "github.com/John6810/terraform-azurerm-modules//DnsResolver?ref=DnsResolver/v1.0.0"

  subscription_acronym = "con"
  environment          = "prod"
  region_code          = "gwc"
  location             = "germanywestcentral"

  virtual_network_id  = "/subscriptions/.../virtualNetworks/vnet-con-prod-gwc-hub"
  inbound_subnet_id   = "/subscriptions/.../subnets/snet-con-prod-gwc-dns-in"
  inbound_private_ip  = "10.238.200.68"
  outbound_subnet_id  = "/subscriptions/.../subnets/snet-con-prod-gwc-dns-out"

  forwarding_rules = {
    onprem = {
      domain_name = "corp.example.com."
      target_dns_servers = [
        { ip_address = "10.0.0.4" },
        { ip_address = "10.0.0.5" }
      ]
    }
  }

  ruleset_vnet_links = {
    hub   = "/subscriptions/.../virtualNetworks/vnet-con-prod-gwc-hub"
    spoke = "/subscriptions/.../virtualNetworks/vnet-api-prod-gwc-spoke"
  }

  tags = { Environment = "Production" }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/DnsResolver"
}

inputs = {
  subscription_acronym = include.sub.locals.subscription_acronym
  environment          = include.root.inputs.environment
  region_code          = include.root.inputs.region_code
  location             = include.root.inputs.location
  virtual_network_id   = dependency.hub_vnet.outputs.id
  inbound_subnet_id    = dependency.subnet.outputs.subnet_ids["snet-con-prod-gwc-dns-in"]
  inbound_private_ip   = "10.238.200.68"
  tags                 = include.root.inputs.common_tags
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| azurerm | ~> 4.0 |
| time | >= 0.9.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | Optional. Explicit name. If null, computed from naming components. | `string` | `null` | No |
| subscription_acronym | Subscription acronym (e.g. con) | `string` | `null` | No |
| environment | Environment (e.g. prod, nprd) | `string` | `null` | No |
| region_code | Region code (e.g. gwc) | `string` | `null` | No |
| location | Azure region | `string` | -- | Yes |
| tags | Tags to apply | `map(string)` | `{}` | No |
| virtual_network_id | VNet ID in which to deploy the resolver | `string` | -- | Yes |
| inbound_subnet_id | Subnet ID for the inbound endpoint (Microsoft.Network/dnsResolvers delegation required) | `string` | -- | Yes |
| inbound_private_ip | Static private IP for the inbound endpoint. If null, dynamic allocation. | `string` | `null` | No |
| outbound_subnet_id | Subnet ID for the outbound endpoint. If null, no outbound endpoint. | `string` | `null` | No |
| forwarding_rules | Map of DNS forwarding rules. Key = rule name. | `map(object({ domain_name = string, target_dns_servers = list(object({ ip_address = string, port = optional(number, 53) })), enabled = optional(bool, true) }))` | `{}` | No |
| ruleset_vnet_links | Map of name => VNet ID to link to the forwarding ruleset | `map(string)` | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| resource_group_name | The name of the resource group |
| id | The ID of the DNS Private Resolver |
| name | The name of the DNS Private Resolver |
| resource | Complete DNS Private Resolver resource object |
| inbound_endpoint_ip | The private IP address of the inbound endpoint (use as DNS forwarder) |
| inbound_endpoint_id | The ID of the inbound endpoint |
| outbound_endpoint_id | The ID of the outbound endpoint (null if not created) |
| forwarding_ruleset_id | The ID of the DNS forwarding ruleset (null if not created) |
