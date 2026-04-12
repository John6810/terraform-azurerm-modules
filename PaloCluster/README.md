# PaloCluster

Deploys a complete Palo Alto VM-Series firewall cluster on Azure. Creates a dedicated resource group, an internal Standard Load Balancer with HA ports on the trust subnet, public IPs for management, zonal VM-Series instances with three NICs each, and optional disk encryption with customer-managed keys and Application Insights monitoring.

## Usage

### Standalone

```hcl
module "palo_cluster" {
  source = "github.com/John6810/terraform-azurerm-modules//PaloCluster?ref=PaloCluster/v1.0.0"

  subscription_acronym = "con"
  environment          = "prod"
  region_code          = "gwc"
  workload             = "palo-obew"
  location             = "germanywestcentral"

  subnet_mgmt_id    = "/subscriptions/.../subnets/snet-con-prod-gwc-mgmt"
  subnet_untrust_id = "/subscriptions/.../subnets/snet-con-prod-gwc-untrust"
  subnet_trust_id   = "/subscriptions/.../subnets/snet-con-prod-gwc-trust"

  ilb_frontend_ip = "10.238.200.36"

  firewalls = {
    "obew-01" = { mgmt_ip = "10.238.200.4", untrust_ip = "10.238.200.20", trust_ip = "10.238.200.37", zone = "1" }
    "obew-02" = { mgmt_ip = "10.238.200.5", untrust_ip = "10.238.200.21", trust_ip = "10.238.200.38", zone = "2" }
  }

  admin_ssh_public_key   = "ssh-rsa AAAA..."
  enable_disk_encryption = true

  tags = { Environment = "Production" }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/PaloCluster"
}

inputs = {
  subscription_acronym = include.sub.locals.subscription_acronym
  environment          = include.root.inputs.environment
  region_code          = include.root.inputs.region_code
  workload             = "palo-obew"
  location             = include.root.inputs.location

  subnet_mgmt_id    = dependency.subnet.outputs.subnet_ids["snet-con-prod-gwc-mgmt"]
  subnet_untrust_id = dependency.subnet.outputs.subnet_ids["snet-con-prod-gwc-untrust"]
  subnet_trust_id   = dependency.subnet.outputs.subnet_ids["snet-con-prod-gwc-trust"]

  ilb_frontend_ip = "10.238.200.36"

  firewalls = {
    "obew-01" = { mgmt_ip = "10.238.200.4", untrust_ip = "10.238.200.20", trust_ip = "10.238.200.37", zone = "1" }
    "obew-02" = { mgmt_ip = "10.238.200.5", untrust_ip = "10.238.200.21", trust_ip = "10.238.200.38", zone = "2" }
  }

  admin_ssh_public_key       = get_env("PALO_SSH_PUBLIC_KEY")
  log_analytics_workspace_id = dependency.law.outputs.id
  tags                       = include.root.inputs.common_tags
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| azurerm | ~> 4.0 |
| time | >= 0.9.0 |
| random | >= 3.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| subscription_acronym | Subscription acronym (e.g. con) | `string` | -- | Yes |
| environment | Environment (e.g. prod, nprd) | `string` | -- | Yes |
| region_code | Region code (e.g. gwc) | `string` | -- | Yes |
| workload | Workload / cluster name (e.g. palo-obew, palo-in) | `string` | -- | Yes |
| location | Azure region | `string` | -- | Yes |
| tags | Tags to assign | `map(string)` | `{}` | No |
| subnet_mgmt_id | Management subnet ID | `string` | -- | Yes |
| subnet_untrust_id | Untrust subnet ID | `string` | -- | Yes |
| subnet_trust_id | Trust subnet ID | `string` | -- | Yes |
| ilb_frontend_ip | Static private IP for the ILB frontend in the trust subnet | `string` | -- | Yes |
| ilb_probe_port | ILB health probe port | `number` | `443` | No |
| ilb_probe_threshold | Consecutive failures before unhealthy | `number` | `2` | No |
| ilb_probe_interval | Health probe interval in seconds | `number` | `5` | No |
| firewalls | Map of firewall instances. Key = name suffix, value = NIC IPs and zone. | `map(object({ mgmt_ip = string, untrust_ip = string, trust_ip = string, zone = optional(string) }))` | -- | Yes |
| vm_size | VM size (4 vCPU, 14 GB RAM minimum recommended) | `string` | `"Standard_DS3_v2"` | No |
| vm_image | Palo Alto VM-Series marketplace image | `object({ publisher = string, offer = string, sku = string, version = string })` | Palo Alto defaults | No |
| panos_version | PAN-OS version (for reference/tags) | `string` | `"11.1.607"` | No |
| admin_username | Admin username for VM-Series instances | `string` | `"panadmin"` | No |
| admin_password | Admin password. Mutually exclusive with admin_ssh_public_key. | `string` | `null` | No |
| admin_ssh_public_key | SSH public key. Mutually exclusive with admin_password. | `string` | `null` | No |
| os_disk_size_gb | OS disk size in GB | `number` | `80` | No |
| os_disk_storage_account_type | OS disk type: Standard_LRS, StandardSSD_LRS, Premium_LRS | `string` | `"Premium_LRS"` | No |
| accelerated_networking | Enable accelerated networking on dataplane NICs | `bool` | `true` | No |
| enable_boot_diagnostics | Enable boot diagnostics for troubleshooting | `bool` | `false` | No |
| boot_diagnostics_storage_uri | Storage account URI for boot diagnostics | `string` | `null` | No |
| enable_disk_encryption | Creates KV + RSA key + DES for CMK disk encryption | `bool` | `true` | No |
| kv_secrets_readers | Entra ID object IDs granted Key Vault Secrets User | `list(string)` | `[]` | No |
| kv_allowed_ips | Public IPs (CIDR /32) allowed to access the KV | `list(string)` | `[]` | No |
| log_analytics_workspace_id | LAW ID for Application Insights. If null, no APPI. | `string` | `null` | No |
| panos_spn_object_id | PAN-OS SPN object ID for custom AppInsights role | `string` | `null` | No |
| bootstrap_storage_account_name | Bootstrap storage account NAME (not ARM ID). If null, no bootstrap. | `string` | `null` | No |
| bootstrap_share_name | File share name for bootstrap | `string` | `null` | No |
| bootstrap_share_directory | Optional subdirectory within the file share | `string` | `null` | No |
| bootstrap_storage_account_access_key | Bootstrap storage account access key | `string` | `null` | No |

## Outputs

| Name | Description |
|------|-------------|
| resource | The full resource group object |
| resource_group_name | Cluster resource group name |
| resource_group_id | Cluster resource group ID |
| ilb_id | Internal Load Balancer ID |
| ilb_frontend_ip | Internal Load Balancer frontend IP |
| ilb_backend_pool_id | Internal Load Balancer backend pool ID |
| disk_encryption_set_id | Disk Encryption Set ID (null if no CMK) |
| key_vault_id | Key Vault ID for disk encryption (null if disabled) |
| des_identity_principal_id | DES managed identity principal ID |
| vm_ids | Map of key => VM ID |
| vm_names | Map of key => VM name |
| mgmt_private_ips | Map of key => management private IP |
| appinsights_instrumentation_keys | Map of key => APPI instrumentation key (sensitive) |
| appinsights_connection_strings | Map of key => APPI connection string (sensitive) |
