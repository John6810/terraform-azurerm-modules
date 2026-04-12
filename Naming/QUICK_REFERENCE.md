###############################################################
# NAMING MODULE - QUICK REFERENCE GUIDE
###############################################################

## BASIC USAGE

```hcl
module "naming" {
  source = "./modules/Naming"

  prefix      = "neko"          # Company/Project prefix
  suffix      = "01"            # Instance number
  environment = "prod"          # dev, test, staging, prod, etc.
  region      = "weu"           # West Europe
}
```

## NAMING OUTPUTS

### Azure Standard Resources
```hcl
module.naming.resource_group_name              # rg-neko-prod-weu-01
module.naming.virtual_network_name             # vnet-neko-prod-weu-01
module.naming.subnet_name                      # snet-neko-prod-weu-01
module.naming.network_security_group_name      # nsg-neko-prod-weu-01
module.naming.route_table_name                 # rt-neko-prod-weu-01
module.naming.public_ip_name                   # pip-neko-prod-weu-01
module.naming.network_interface_name           # nic-neko-prod-weu-01
module.naming.virtual_machine_name             # vm-neko-prod-weu-01
module.naming.storage_account_name             # stnekoprodweu01 (sanitized)
module.naming.key_vault_name                   # kv-neko-prod-weu-01
module.naming.log_analytics_workspace_name     # log-neko-prod-weu-01
```

### Palo Alto Specific Names
```hcl
module.naming.palo_alto_names.vm_series        # neko-palofw-prod-weu-01
module.naming.palo_alto_names.interface        # neko-paloif-prod-weu-01
module.naming.palo_alto_names.zone             # neko-palozone-prod-weu-01
module.naming.palo_alto_names.virtual_router   # neko-palovr-prod-weu-01
module.naming.palo_alto_names.security_policy  # neko-palopol-prod-weu-01
```

### Custom Resource Names
```hcl
module.naming.custom_names["palo_alto_vm_series"]
module.naming.custom_names["route_table_route"]
module.naming.custom_names["nsg_security_rule"]
```

## USING WITH SUFFIXES (Multiple Variations)

```hcl
module "naming" {
  source = "./modules/Naming"

  prefix      = "neko"
  environment = "prod"
  region      = "weu"
  
  name_suffixes = ["hub", "spoke-app", "spoke-data"]
}

# Access built names
module.naming.built_names.resource_group["hub"]        # neko-rg-hub-prod-weu
module.naming.built_names.resource_group["spoke-app"]  # neko-rg-spoke-app-prod-weu
```

## COMMON USAGE PATTERNS

### Pattern 1: Basic Resource
```hcl
resource "azurerm_resource_group" "example" {
  name     = "${module.naming.resource_group_name}-hub"
  location = "westeurope"
}
```

### Pattern 2: Palo Alto Firewall
```hcl
resource "azurerm_linux_virtual_machine" "palo_alto" {
  name                = "${module.naming.palo_alto_names.vm_series}-hub"
  resource_group_name = azurerm_resource_group.hub.name
  # ...
}
```

### Pattern 3: Network Interfaces
```hcl
resource "azurerm_network_interface" "palo_mgmt" {
  name = "${module.naming.palo_alto_names.interface}-mgmt"
  # ...
}
```

### Pattern 4: Multiple Environments
```hcl
module "naming" {
  for_each = toset(["dev", "staging", "prod"])
  
  source      = "./modules/Naming"
  prefix      = "neko"
  environment = each.key
  region      = "weu"
}

resource "azurerm_resource_group" "env" {
  for_each = module.naming
  
  name     = "${each.value.resource_group_name}-app"
  location = "westeurope"
}
```

## CUSTOM RESOURCE TYPES

### Add Your Own Types
```hcl
module "naming" {
  source = "./modules/Naming"
  
  prefix      = "neko"
  environment = "prod"
  region      = "weu"
  
  custom_resource_types = {
    "fortinet_firewall" = "fgfw"
    "f5_load_balancer"  = "f5lb"
    "nginx_proxy"       = "nginx"
  }
}

# Use custom type
resource "azurerm_linux_virtual_machine" "fortinet" {
  name = "${module.naming.custom_names.fortinet_firewall}-hub"
  # ...
}
```

## BUILT-IN CUSTOM TYPES

| Type                          | Short Name | Example Output           |
| ----------------------------- | ---------- | ------------------------ |
| palo_alto_vm_series           | palofw     | neko-palofw-prod-weu-01  |
| palo_alto_interface           | paloif     | neko-paloif-prod-weu-01  |
| palo_alto_zone                | palozone   | neko-palozone-prod-weu-01|
| palo_alto_virtual_router      | palovr     | neko-palovr-prod-weu-01  |
| palo_alto_security_policy     | palopol    | neko-palopol-prod-weu-01 |
| route_table_route             | route      | neko-route-prod-weu-01   |
| nsg_security_rule             | nsgr       | neko-nsgr-prod-weu-01    |
| custom_vm                     | vm         | neko-vm-prod-weu-01      |
| custom_nic                    | nic        | neko-nic-prod-weu-01     |

## NAMING CONVENTION FORMAT

Default: `{prefix}-{type}-{name}-{env}-{region}-{suffix}`

Examples:
- Resource Group: `neko-rg-hub-prod-weu-01`
- VNet: `neko-vnet-hub-prod-weu-01`
- Palo Alto: `neko-palofw-hub-prod-weu-01`

## ENVIRONMENT CODES

Recommended short codes:
- `dev` - Development
- `test` - Testing
- `staging` - Staging
- `uat` - User Acceptance Testing
- `prod` - Production
- `dr` - Disaster Recovery
- `sandbox` - Sandbox
- `lab` - Laboratory

## REGION CODES

Common Azure region codes:
- `weu` - West Europe
- `neu` - North Europe
- `eus` - East US
- `eus2` - East US 2
- `wus` - West US
- `cus` - Central US
- `frc` - France Central
- `ukso` - UK South
- `sea` - Southeast Asia

## VALIDATION ERRORS

### Error: "Prefix should not exceed 10 characters"
**Solution**: Shorten your prefix.

### Error: "Environment must be one of: dev, test, staging..."
**Solution**: Use a valid environment code or disable validation with `validate_names = false`.

### Error: "Region code should not exceed 5 characters"
**Solution**: Use shorter region codes (e.g., "weu" instead of "westeurope").

## TIPS

1. **Consistent Prefix**: Use company or project name
2. **Short Regions**: Use 3-4 letter codes
3. **Numeric Suffixes**: Use 01, 02, etc. for multiple instances
4. **Storage Names**: Always use `module.naming.storage_account_name` (auto-sanitized)
5. **Built Names**: Use `name_suffixes` for multiple variations
6. **Validation**: Keep enabled to catch errors early

## COMPLETE EXAMPLE

```hcl
# Module declaration
module "naming" {
  source = "./modules/Naming"

  prefix      = "neko"
  suffix      = "01"
  environment = "prod"
  region      = "weu"
  
  name_suffixes = ["hub", "mgmt", "untrust", "trust"]
}

# Resource Group
resource "azurerm_resource_group" "hub" {
  name     = "${module.naming.resource_group_name}-hub"
  location = "westeurope"
}

# Virtual Network
resource "azurerm_virtual_network" "hub" {
  name                = "${module.naming.virtual_network_name}-hub"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  address_space       = ["10.0.0.0/16"]
}

# Palo Alto Firewall
resource "azurerm_linux_virtual_machine" "palo_alto" {
  name                = "${module.naming.palo_alto_names.vm_series}-hub"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  size                = "Standard_D3_v2"
  # ... rest of config
}

# Network Interfaces
resource "azurerm_network_interface" "palo_mgmt" {
  name                = module.naming.built_names.palo_alto_interface["mgmt"]
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  # ... rest of config
}

resource "azurerm_network_interface" "palo_untrust" {
  name                = module.naming.built_names.palo_alto_interface["untrust"]
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  # ... rest of config
}

resource "azurerm_network_interface" "palo_trust" {
  name                = module.naming.built_names.palo_alto_interface["trust"]
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  # ... rest of config
}
```

## MIGRATION FROM AZURE MODULE ONLY

If migrating from the Azure naming module:

```hcl
# OLD
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.4.0"
  prefix  = "neko"
}

# NEW (drop-in replacement)
module "naming" {
  source      = "./modules/Naming"
  prefix      = "neko"
  environment = "prod"
  region      = "weu"
}

# All existing references still work!
# module.naming.resource_group_name
# module.naming.virtual_network_name
# etc.
```
