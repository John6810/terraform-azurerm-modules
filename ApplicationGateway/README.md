# ApplicationGateway

Deploys an Azure Application Gateway v2 (WAF_v2 SKU) with a WAF Policy (OWASP 3.2 + Bot Manager), autoscaling, zone redundancy, and optional public IP. Includes a default placeholder backend for AGIC or manual configuration.

## Usage

### Standalone

```hcl
module "application_gateway" {
  source = "github.com/John6810/terraform-azurerm-modules//ApplicationGateway?ref=ApplicationGateway/v1.0.0"

  subscription_acronym = "api"
  environment          = "prod"
  region_code          = "gwc"
  workload             = "001"
  location             = "germanywestcentral"
  resource_group_name  = "rg-api-prod-gwc-appgw"
  appgw_subnet_id      = "/subscriptions/.../subnets/snet-api-prod-gwc-appgw"

  create_public_ip   = false
  private_ip_address = "10.238.10.10"
  waf_mode           = "Prevention"
  min_capacity       = 1
  max_capacity       = 3

  tags = { Environment = "Production" }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/ApplicationGateway"
}

inputs = {
  subscription_acronym = include.sub.locals.subscription_acronym
  environment          = include.root.inputs.environment
  region_code          = include.root.inputs.region_code
  workload             = "001"
  location             = include.root.inputs.location
  resource_group_name  = dependency.rg.outputs.name
  appgw_subnet_id      = dependency.subnet.outputs.subnet_ids[include.sub.locals.networks.corp_apimanager.subnets.appgw.name]
  create_public_ip     = false
  private_ip_address   = "10.238.10.10"
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
| name | Explicit name. If null, computed from naming components. | `string` | `null` | No |
| subscription_acronym | Subscription acronym | `string` | `null` | No |
| environment | Environment | `string` | `null` | No |
| region_code | Region code | `string` | `null` | No |
| workload | Workload suffix | `string` | `null` | No |
| location | Azure region | `string` | -- | Yes |
| resource_group_name | Resource group name | `string` | -- | Yes |
| appgw_subnet_id | Dedicated subnet ID for the Application Gateway | `string` | -- | Yes |
| create_public_ip | Create a public IP (PoC only, Prod goes through Palo Alto FW) | `bool` | `true` | No |
| private_ip_address | Static private IP for the private frontend | `string` | `null` | No |
| waf_mode | WAF mode: Detection, Prevention | `string` | `"Prevention"` | No |
| min_capacity | Minimum capacity (autoscale) | `number` | `1` | No |
| max_capacity | Maximum capacity (autoscale) | `number` | `3` | No |
| availability_zones | Availability zones | `list(string)` | `["1", "2", "3"]` | No |
| tags | Tags | `map(string)` | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| id | Application Gateway ID |
| name | Application Gateway name |
| waf_policy_id | WAF Policy ID |
| public_ip_address | Public IP address (if created) |
| private_ip_address | Private IP address of the frontend |
