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

## Code Standards

- **Terraform version:** >= 1.5.0
- **AzureRM provider:** ~> 4.0
- Run `terraform fmt -recursive` before committing
- Run `terraform validate` on your module
- All variables must have `description` and explicit `type`
- All outputs must have `description`

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
