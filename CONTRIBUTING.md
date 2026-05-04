# Contributing

Thank you for your interest in contributing to this project!

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Create a feature branch: `git checkout -b feature/my-module-improvement`
4. Make your changes
5. Submit a pull request

## Module Structure

Every module must follow this structure:

```
{ModuleName}/
├── version.tf      # Required providers and versions
├── variables.tf    # Input variables with descriptions and types
├── main.tf         # Resource definitions
└── output.tf       # Output values
```

### Naming logic

All modules compute their resource name using:

```hcl
locals {
  computed_name = "{prefix}-${var.subscription_acronym}-${var.environment}-${var.region_code}-${var.workload}"
  name          = var.name != null ? var.name : local.computed_name
}
```

The `name` variable allows users to override the computed name.

> **Why is this pattern duplicated in every module instead of centralized in a shared `Naming` module?**
>
> A historical `Naming` module wrapped `Azure/naming/azurerm` + custom Palo types but was never adopted by any caller (deleted 2026-05-04, see [REVIEW/SPRINT-7-AUDIT.md](REVIEW/SPRINT-7-AUDIT.md)). The repo now relies on convention + per-module validators (`subscription_acronym` regex, `environment` regex, etc.) duplicated 44 ×. This is **conscious tech debt**, accepted because the convention is simple, stable, and the validators catch deviating inputs at plan time. A future Sprint may reintroduce a centralized naming module if a new naming requirement emerges (extra segment, env outside `^[a-z]{2,4}$`, etc.) — see the audit doc for the trigger conditions and migration plan.

## Code Standards

- **Terraform version:** >= 1.5.0
- **AzureRM provider:** ~> 4.0
- Run `terraform fmt -recursive` before committing
- Run `terraform validate` on your module
- All variables must have `description` and explicit `type`
- All outputs must have `description`

### Role assignment shapes

Two canonical shapes exist for `role_assignments` / `identity_role_assignments`. Pick the one matching the module's RBAC pattern:

**Shape A — principal_id-based** (the module's primary resource is the *receiver* of the role; principal is external).

Used by: `KeyVault`, `KeyVaultStack`, `ContainerRegistry`, `StorageAccount`, `ResourceGroup`, `ResourceGroupSet`.

```hcl
type = map(object({
  role_definition_id_or_name             = string
  principal_id                           = string
  principal_type                         = optional(string)            # User | Group | ServicePrincipal
  condition                              = optional(string)
  condition_version                      = optional(string)
  description                            = optional(string)
  skip_service_principal_aad_check       = optional(bool, false)
  delegated_managed_identity_resource_id = optional(string)
}))
```

**Shape B — scope-based** (the module's primary resource is a *managed identity*; the MI is the principal, caller specifies target scopes).

Used by: `ManagedIdentity`, `Grafana` (`identity_role_assignments`).

```hcl
type = map(object({
  role_definition_id_or_name             = string
  scope                                  = string
  condition                              = optional(string)
  condition_version                      = optional(string)
  description                            = optional(string)
  skip_service_principal_aad_check       = optional(bool, false)
  delegated_managed_identity_resource_id = optional(string)
}))
# principal_id is hardcoded in main.tf to the MI's principal_id
# principal_type is hardcoded to "ServicePrincipal" (MIs are SPNs)
```

Both shapes carry the same 5 optional fields; `principal_type` is only relevant in Shape A (Shape B's principal is by construction always a managed identity / SP). Do not invent a third shape — extend Shape A or B as needed.

`RbacAssignments` is a special bulk-assignment module with its own `group_assignments` / `identity_assignments` split (resolves principals by display_name vs object_id) and is not subject to this convention.

## Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(Aks): add support for confidential nodes
fix(KeyVault): correct soft delete retention default
docs(PaloCluster): add HA deployment example
```

## Releasing

Modules are released individually via Git tags:

```
{ModuleName}/v{MAJOR}.{MINOR}.{PATCH}
```

Example: `Aks/v1.2.0`, `KeyVault/v2.0.1`

Only maintainers can create release tags.

## Questions?

Open an issue for discussion before starting large changes.
