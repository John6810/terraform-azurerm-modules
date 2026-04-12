# ResourceLock

Applies management locks (CanNotDelete or ReadOnly) to one or more existing Azure scopes (resource groups or individual resources), with a flag to disable all locks for maintenance operations.

## Usage

### Standalone

```hcl
module "resource_lock" {
  source = "github.com/John6810/terraform-azurerm-modules//ResourceLock?ref=ResourceLock/v1.0.0"

  locks = {
    rg_network = {
      scope = "/subscriptions/.../resourceGroups/rg-api-prod-gwc-network"
      name  = "lock-rg-network"
      notes = "VNet, subnets, peerings — deletion causes connectivity loss"
    }
    rg_aks = {
      scope      = "/subscriptions/.../resourceGroups/rg-api-prod-gwc-aks"
      name       = "lock-rg-aks"
      lock_level = "ReadOnly"
    }
  }
}
```

### Terragrunt

```hcl
terraform {
  source = "${get_repo_root()}/modules/ResourceLock"
}

inputs = {
  locks = {
    rg_network = {
      scope = dependency.rg_network.outputs.id
      name  = "lock-rg-network"
    }
    rg_aks = {
      scope = dependency.rg_aks.outputs.id
      name  = "lock-rg-aks"
    }
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| azurerm | ~> 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| locks | Map of management locks. Key is arbitrary. | `map(object({...}))` | -- | Yes |
| enable_locks | Set to false to disable all locks (e.g. maintenance destroy) | `bool` | `true` | No |

### Lock Object

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| scope | `string` | Yes | -- | Azure resource ID to lock |
| name | `string` | No | `"lock-CanNotDelete"` | Lock name |
| lock_level | `string` | No | `"CanNotDelete"` | `CanNotDelete` or `ReadOnly` |
| notes | `string` | No | auto | Lock description |

## Outputs

| Name | Description |
|------|-------------|
| ids | Map of lock key => lock ID |
| resources | Map of lock key => complete lock resource object |
