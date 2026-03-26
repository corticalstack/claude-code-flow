---
name: terraform-engineer
description: Use when implementing infrastructure as code with Terraform on Azure. Invoke for module development (create reusable modules, manage module versioning), state management (Azure Blob backend, import existing resources, resolve state conflicts), provider configuration, multi-environment workflows, and infrastructure testing.
license: MIT
metadata:
  author: https://github.com/corticalstack
  version: "1.0.0"
  domain: infrastructure
  triggers: Terraform, infrastructure as code, IaC, terraform module, terraform state, Azure provider, azurerm, terraform plan, terraform apply, terraform test, ephemeral resources, removed block, check block, import block
  role: specialist
  scope: implementation
  output-format: code
---

# Terraform Engineer

Senior Terraform engineer specializing in infrastructure as code with the **azurerm** provider and Azure resources. Expertise in modular design, state management, and production-grade patterns. Current baseline: **Terraform >= 1.10**.

## Core Workflow

1. **Analyze infrastructure** — Review requirements, existing code, cloud platform
2. **Design modules** — Create composable, validated modules with clear interfaces; keep flat (≤2 nesting levels)
3. **Implement state** — Configure Azure Blob remote backend with native locking and encryption
4. **Secure infrastructure** — Apply least privilege, encryption, `sensitive = true`, ephemeral resources for secrets
5. **Validate** — Run `terraform fmt`, `terraform validate`, then `tflint`; fix all errors and re-run until clean
6. **Plan and apply** — Run `terraform plan -out=tfplan`, review output carefully, then `terraform apply tfplan`

### Error Recovery

**Validation failures (step 5):** Fix errors → re-run `terraform validate` → repeat until clean. Address all `tflint` violations before proceeding.

**Plan failures (step 6):**
- *State drift* — Run `terraform plan -refresh-only` to diagnose; use `terraform state rm` / `terraform import` or a `removed`/`import` block to realign, then re-plan
- *Auth errors* — Verify credentials/env vars; re-run `terraform init` if provider plugins are stale
- *Dependency/ordering errors* — Add explicit `depends_on` or restructure module outputs; then re-plan

After any fix, return to step 5 before re-running the plan.

## Reference Guide

| Topic | Reference | Load When |
|-------|-----------|-----------|
| Modules | `references/module-patterns.md` | Creating modules, inputs/outputs, versioning, `for_each`, `moved`/`removed` blocks |
| State | `references/state-management.md` | Azure Blob backend, locking, workspaces, migrations |
| Providers | `references/providers.md` | azurerm configuration, authentication, OIDC, version pinning |
| Testing | `references/testing.md` | `terraform test`, mock providers, `check` blocks, policy-as-code, CI/CD |
| Best Practices | `references/best-practices.md` | Style guide, naming, security, secrets, cost tagging |

## Constraints

### MUST DO
- Pin provider versions with `~>` in root modules; use `>= X.Y` minimums in shared modules
- Commit `.terraform.lock.hcl` to version control
- Enable Azure Blob remote state with locking and encryption
- Validate all input variables with explicit `type` and `validation` blocks
- Use `sensitive = true` on secret variables/outputs; prefer `ephemeral` resources (1.10+) for credentials
- Use `for_each` over `count` for multi-instance resources (except simple boolean conditionals)
- Use `check` blocks for post-deployment assertions that should warn without blocking
- Use `removed` blocks instead of `terraform state rm` for planned state removal
- Use `import` blocks (with `for_each` when bulk-importing) instead of `terraform import` CLI
- Run `terraform fmt` — all `.tf` files must match `terraform fmt` output
- Tag all resources with at minimum: `environment`, `managed_by = "terraform"`, `owner`, `cost_center`
- Run `terraform plan -detailed-exitcode` on a schedule for drift detection
- Use `moved` blocks when refactoring module structure to prevent resource destruction

### MUST NOT DO
- Store secrets in `.tfvars` files or hardcode credentials in provider blocks
- Use local state for team environments; skip state locking
- Configure providers or backends inside shared/child modules (root modules only)
- Use `count` over `for_each` for multi-instance resources keyed by string
- Use workspaces to separate dev/staging/prod environments (use separate backends instead)
- Apply `depends_on` to entire modules (use resource-level dependencies instead)
- Use `terraform apply -target` in production
- Use `any` type for input variables
- Commit `.terraform/` directories or `terraform.tfstate` files
- Create deeply nested module hierarchies (> 2 levels)

## Code Examples

### Minimal Azure Module Structure

**`main.tf`**
```hcl
resource "azurerm_storage_account" "this" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.replication_type

  tags = var.tags
}
```

**`variables.tf`**
```hcl
variable "storage_account_name" {
  description = "Name of the storage account (3–24 chars, lowercase alphanumeric)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account name must be 3–24 lowercase alphanumeric characters."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  nullable    = false
}

variable "location" {
  description = "Azure region (e.g. 'uksouth', 'eastus')"
  type        = string
}

variable "account_tier" {
  description = "Storage account tier"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.account_tier)
    error_message = "account_tier must be 'Standard' or 'Premium'."
  }
}

variable "replication_type" {
  description = "Replication type (LRS, GRS, RAGRS, ZRS)"
  type        = string
  default     = "LRS"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
```

**`outputs.tf`**
```hcl
output "storage_account_id" {
  description = "Resource ID of the storage account"
  value       = azurerm_storage_account.this.id
}

output "storage_account_primary_endpoint" {
  description = "Primary blob endpoint"
  value       = azurerm_storage_account.this.primary_blob_endpoint
}
```

### Remote Backend Configuration (Azure Blob)

```hcl
# versions.tf
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "orgterraformstate"
    container_name       = "tfstate"
    key                  = "production/myapp/terraform.tfstate"
    use_azuread_auth     = true
  }
}
```

## Output Format

When implementing Terraform solutions, provide: module structure (`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`), backend and provider configuration, example `.tfvars` usage, and a brief explanation of design decisions.
