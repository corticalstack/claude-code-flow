# Terraform Module Patterns

## Module Structure

```
terraform-azurerm-storage/
├── main.tf           # Primary resource definitions
├── variables.tf      # Input variable declarations (alphabetical)
├── outputs.tf        # Output value definitions (alphabetical)
├── versions.tf       # Provider version constraints
├── locals.tf         # Local values
├── README.md         # Module documentation (auto-generated via terraform-docs)
├── examples/
│   └── complete/
│       ├── main.tf
│       └── variables.tf
└── tests/
    ├── unit.tftest.hcl
    └── integration.tftest.hcl
```

## Basic Module Pattern (Azure Storage Account)

**`main.tf`**
```hcl
resource "azurerm_storage_account" "this" {
  name                      = var.name
  resource_group_name       = var.resource_group_name
  location                  = var.location
  account_tier              = var.account_tier
  account_replication_type  = var.replication_type
  enable_https_traffic_only = true
  min_tls_version           = "TLS1_2"

  tags = merge(var.tags, { Name = var.name })
}

resource "azurerm_storage_container" "this" {
  for_each = var.containers

  name                  = each.key
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = each.value.access_type
}
```

**`variables.tf`**
```hcl
variable "name" {
  description = "Storage account name (3–24 chars, lowercase alphanumeric)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.name))
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
  description = "Replication type (LRS, GRS, ZRS, GZRS)"
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.replication_type)
    error_message = "replication_type must be one of LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS."
  }
}

variable "containers" {
  description = "Map of container names to configuration"
  type = map(object({
    access_type = string
  }))
  default = {}
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

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.this.name
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob service endpoint"
  value       = azurerm_storage_account.this.primary_blob_endpoint
}

output "storage_account_primary_access_key" {
  description = "Primary access key (sensitive)"
  value       = azurerm_storage_account.this.primary_access_key
  sensitive   = true
}
```

**`versions.tf`**
```hcl
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"   # Minimum only in shared modules; callers pin exact version
    }
  }
}
```

## Module Composition

```hcl
# Root module composing child modules
module "networking" {
  source = "./modules/vnet"

  name                = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  address_space       = ["10.0.0.0/16"]

  subnets = {
    app  = { address_prefix = "10.0.1.0/24", service_endpoints = ["Microsoft.Storage"] }
    data = { address_prefix = "10.0.2.0/24", service_endpoints = ["Microsoft.Sql"] }
  }

  tags = local.common_tags
}

module "storage" {
  source = "./modules/storage"

  name                = "st${replace(local.name_prefix, "-", "")}data"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  # Pass outputs from networking module to storage
  allowed_subnet_ids = [module.networking.subnet_ids["app"]]

  tags = local.common_tags
}
```

## Dynamic Blocks

```hcl
variable "security_rules" {
  type = map(object({
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
  }))
}

resource "azurerm_network_security_group" "this" {
  name                = "nsg-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location

  dynamic "security_rule" {
    for_each = var.security_rules

    content {
      name                       = security_rule.key
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }

  tags = var.tags
}
```

## Conditional Resources

```hcl
# count for simple boolean
resource "azurerm_private_endpoint" "storage" {
  count = var.enable_private_endpoint ? 1 : 0

  name                = "pep-${var.name}-storage"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "psc-${var.name}-storage"
    private_connection_resource_id = azurerm_storage_account.this.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
}

# for_each for conditional map of resources
resource "azurerm_storage_container" "backup" {
  for_each = var.enable_backup ? { "backup" = { access_type = "private" } } : {}

  name                  = each.key
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = each.value.access_type
}
```

## Module Versioning

```hcl
# Pin to specific version — recommended for production
module "storage" {
  source  = "app.terraform.io/myorg/storage/azurerm"
  version = "2.3.1"
}

# Use version constraints for flexibility
module "aks" {
  source  = "app.terraform.io/myorg/aks/azurerm"
  version = "~> 3.0"   # >= 3.0, < 4.0
}

# Reference Git tag for custom modules
module "custom_network" {
  source = "git::https://github.com/myorg/terraform-modules.git//network?ref=v1.2.3"
}
```

Use **SemVer** (`MAJOR.MINOR.PATCH`):
- MAJOR: breaking changes requiring consumer updates
- MINOR: new backward-compatible features
- PATCH: bug fixes

Maintain a `CHANGELOG.md`. Automate documentation with `terraform-docs`.

## Import Block (Terraform 1.5+, `for_each` support in 1.7+)

```hcl
# Import single existing resource into state
import {
  to = azurerm_resource_group.main
  id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-existing"
}

# Bulk import with for_each (Terraform 1.7+)
locals {
  existing_storage_accounts = {
    logs = "/subscriptions/00000000/resourceGroups/rg-main/providers/Microsoft.Storage/storageAccounts/stlogs"
    data = "/subscriptions/00000000/resourceGroups/rg-main/providers/Microsoft.Storage/storageAccounts/stdata"
  }
}

import {
  for_each = local.existing_storage_accounts
  to       = azurerm_storage_account.this[each.key]
  id       = each.value
}
```

## `removed` Block (Terraform 1.7+)

Use `removed` blocks instead of `terraform state rm` for planned, reviewable state removal:

```hcl
# Remove resource from state without destroying it
removed {
  from = azurerm_storage_container.legacy

  lifecycle {
    destroy = false   # false = remove from state only; true = destroy real resource
  }
}
```

## `moved` Block (Refactoring)

Use `moved` blocks when renaming resources or restructuring modules to prevent unnecessary destroy/create:

```hcl
# Rename resource within the same module
moved {
  from = azurerm_storage_account.old_name
  to   = azurerm_storage_account.this
}

# Move resource into a module
moved {
  from = azurerm_storage_account.main
  to   = module.storage.azurerm_storage_account.this
}

# Move resource between module instances (for_each key change)
moved {
  from = module.storage["old-key"]
  to   = module.storage["new-key"]
}
```

## Cross-Variable Validation (Terraform 1.9+)

```hcl
variable "replication_type" {
  type    = string
  default = "LRS"
}

variable "enable_geo_redundancy" {
  type    = bool
  default = false
}

variable "environment" {
  type = string
}

# Cross-variable validation — reference other variables in condition
variable "account_tier" {
  type        = string
  description = "Storage tier"

  validation {
    # Validate that Premium tier is not used in development
    condition     = !(var.account_tier == "Premium" && var.environment == "development")
    error_message = "Premium storage tier is not permitted in development environments."
  }

  validation {
    # Validate geo-redundancy configuration consistency
    condition     = !var.enable_geo_redundancy || contains(["GRS", "RAGRS", "GZRS", "RAGZRS"], var.replication_type)
    error_message = "enable_geo_redundancy requires a geo-redundant replication_type (GRS, RAGRS, GZRS, or RAGZRS)."
  }
}
```

## Best Practices

- Keep modules focused and single-purpose — do one thing well
- **Never configure providers or backends in shared/child modules** — root modules only
- Use `for_each` over `count` for all multi-resource creation (except simple booleans)
- Validate all inputs with `validation` blocks; use `nullable = false` for required values
- Document all variables and outputs with `description`
- Use `moved` blocks when refactoring to prevent resource destruction
- Use `removed` blocks instead of `terraform state rm` for plannable state removal
- Use `import` blocks (with `for_each` for bulk) instead of CLI `terraform import`
- Use cross-variable `validation` (1.9+) for invariants that span multiple inputs
- Provide complete examples in `examples/complete/`
- Automate documentation with `terraform-docs` in pre-commit hooks
