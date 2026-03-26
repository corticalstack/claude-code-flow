# Terraform Best Practices

Sources: [Google Cloud Style Guide](https://docs.cloud.google.com/docs/terraform/best-practices/general-style-structure), [HashiCorp Style Guide](https://developer.hashicorp.com/terraform/language/style)

## File Structure and Organization

### Canonical File Layout

| File | Purpose |
|------|---------|
| `main.tf` | Primary resource definitions and module calls |
| `variables.tf` | All input variable declarations (alphabetical) |
| `outputs.tf` | All output declarations (alphabetical) |
| `locals.tf` | Local value definitions |
| `providers.tf` | Provider configuration blocks |
| `versions.tf` | `required_version` and `required_providers` |
| `backend.tf` | Backend configuration (keep separate from `versions.tf`) |
| `data.tf` | Data sources (or inline near consuming resources) |

For complex modules, split by concern when a single topic exceeds ~150 lines: `network.tf`, `compute.tf`, `storage.tf`, `iam.tf`.

### Directory Structure

```
.
├── main.tf
├── variables.tf
├── outputs.tf
├── locals.tf
├── providers.tf
├── versions.tf
├── README.md
├── examples/
│   └── complete/
│       ├── main.tf
│       └── variables.tf
├── modules/          # Nested submodules (max 2 levels deep)
├── tests/            # .tftest.hcl files
├── files/            # Static content referenced by Terraform
└── templates/        # .tftpl files for templatefile()
```

For environment separation, use an `envs/` directory with per-environment `.tfvars` files rather than separate directories or workspaces:

```
envs/
├── dev.tfvars
├── staging.tfvars
└── prod.tfvars
```

## Code Style

### Formatting Rules

- Indent with **2 spaces** per nesting level (never tabs) — enforced by `terraform fmt`
- Align `=` signs for consecutive single-line arguments in the same block
- Use `#` exclusively for comments (not `//` or `/* */`)
- Never use multiple ternary operations on a single line; extract to `locals`
- All `.tf` files must conform to `terraform fmt` — run automatically in CI as a blocking gate

### Argument Ordering Within Blocks

```hcl
resource "azurerm_linux_virtual_machine" "app" {
  # 1. count / for_each first, separated by blank line
  for_each = var.instances

  # 2. Required arguments
  name                = "vm-${each.key}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = local.vm_size[var.environment]
  admin_username      = var.admin_username

  # 3. Optional arguments / nested blocks
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  # 4. tags last, separated by blank line
  tags = merge(local.common_tags, { Role = "application" })

  # 5. depends_on after tags, separated by blank line
  depends_on = [azurerm_subnet.app]

  # 6. lifecycle last, separated by blank line
  lifecycle {
    create_before_destroy = true
    prevent_destroy       = var.environment == "production"
  }
}
```

## DRY Principles

### Use Modules for Reusability

```hcl
# Bad — repeated resource blocks
resource "azurerm_resource_group" "app1" {
  name     = "rg-app1-prod"
  location = "uksouth"
}

resource "azurerm_resource_group" "app2" {
  name     = "rg-app2-prod"
  location = "uksouth"
}

# Good — module
module "rg_app1" {
  source      = "./modules/resource-group"
  name        = "app1"
  environment = var.environment
  location    = var.location
  tags        = local.common_tags
}

module "rg_app2" {
  source      = "./modules/resource-group"
  name        = "app2"
  environment = var.environment
  location    = var.location
  tags        = local.common_tags
}
```

### Use Locals for Computed Values

```hcl
locals {
  common_tags = {
    environment  = var.environment
    managed_by   = "terraform"
    owner        = var.team_name
    cost_center  = var.cost_center
    application  = var.application_name
    repository   = var.repo_url
  }

  name_prefix = "${var.project_name}-${var.environment}"

  # Environment-based sizing
  vm_size = {
    production  = "Standard_D4s_v3"
    staging     = "Standard_D2s_v3"
    development = "Standard_B2ms"
  }

  sql_sku = {
    production  = "GP_Gen5_4"
    staging     = "GP_Gen5_2"
    development = "Basic"
  }
}
```

### Use `for_each` Over `count` for Multi-Instance Resources

**Prefer `for_each`**: resources are keyed by string — insertions/removals only affect the changed key, not the whole list.

**Use `count`**: only for simple boolean conditionals (`count = var.enable_feature ? 1 : 0`).

```hcl
# Bad — count with list; causes unnecessary destroys on list reordering
resource "azurerm_subnet" "app" {
  count = length(var.subnet_prefixes)

  name                 = "snet-${count.index}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_prefixes[count.index]]
}

# Good — for_each with map, stable string keys
variable "subnets" {
  type = map(object({
    address_prefix = string
  }))
  default = {
    app  = { address_prefix = "10.0.1.0/24" }
    data = { address_prefix = "10.0.2.0/24" }
    mgmt = { address_prefix = "10.0.3.0/24" }
  }
}

resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                 = "snet-${each.key}-${var.environment}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [each.value.address_prefix]
}
```

### Use Data Sources Instead of Hardcoding

```hcl
# Bad — hardcoded resource ID
resource "azurerm_role_assignment" "app" {
  scope                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/my-rg"
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

# Good — dynamic lookup
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

resource "azurerm_role_assignment" "app" {
  scope                = data.azurerm_resource_group.main.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}
```

## Naming Conventions

### Resource and Data Source Names

- Use **snake_case** throughout
- Do not repeat the resource type in the name: `resource "azurerm_subnet" "app"` not `resource "azurerm_subnet" "app_subnet"`
- Use `this` or `main` for the single resource of a type in a module; descriptive names for multiples
- Use singular nouns
- For **string values** (names, DNS entries, tags): use dashes not underscores (follows Azure naming conventions)

```hcl
# Good
resource "azurerm_virtual_network" "main" {}
resource "azurerm_subnet" "app" {}
resource "azurerm_network_security_group" "web" {}

# Bad
resource "azurerm_virtual_network" "virtual_network" {}   # Type repeated
resource "azurerm_subnet" "my_app_subnet_resource" {}     # Verbose
```

### Variables

```hcl
variable "disk_size_gb" {}           # Include units in name
variable "timeout_seconds" {}
variable "enable_monitoring" {}      # Positive boolean
variable "subnet_ids" {}             # Plural for list/map
variable "max_instance_count" {}     # snake_case, not camelCase
```

### Outputs

Pattern: `{resource_name}_{resource_type}_{attribute}`

```hcl
output "storage_account_id" {}
output "storage_account_primary_endpoint" {}
output "key_vault_uri" {}
output "aks_cluster_fqdn" {}
```

## Security Best Practices

### Secrets Management — Layered Approach

```hcl
# Layer 1 — sensitive = true suppresses CLI output but does NOT prevent storage in state
variable "db_password" {
  description = "Database administrator password"
  type        = string
  sensitive   = true
  nullable    = false
}

# Layer 2 — retrieve from Azure Key Vault via data source (still stored in state)
data "azurerm_key_vault_secret" "db_password" {
  name         = "db-admin-password"
  key_vault_id = data.azurerm_key_vault.main.id
}

# Layer 3 (best — Terraform 1.10+) — ephemeral resource
# NEVER stored in plan files or state files
ephemeral "azurerm_key_vault_secret" "db_password" {
  name         = "db-admin-password"
  key_vault_id = data.azurerm_key_vault.main.id
}

resource "azurerm_mssql_server" "main" {
  name                         = "sql-${local.name_prefix}"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  version                      = "12.0"
  administrator_login          = var.admin_username
  administrator_login_password = ephemeral.azurerm_key_vault_secret.db_password.value

  tags = local.common_tags
}
```

Anti-patterns:
- Never commit `.tfvars` files containing secrets to version control
- Never hardcode credentials in provider blocks
- Never output secrets without `sensitive = true`
- Use `ggshield` or `git-secrets` as pre-commit hooks and CI scanners

### Least Privilege IAM

```hcl
# Prefer Managed Identity over service principals with secrets
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-${local.name_prefix}-app"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = local.common_tags
}

# Scope role assignments to minimum required scope (resource, not subscription)
resource "azurerm_role_assignment" "app_storage_reader" {
  scope                = azurerm_storage_account.data.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}
```

### Encryption at Rest

```hcl
resource "azurerm_storage_account" "data" {
  name                      = "st${replace(local.name_prefix, "-", "")}data"
  resource_group_name       = var.resource_group_name
  location                  = var.location
  account_tier              = "Standard"
  account_replication_type  = "GRS"
  enable_https_traffic_only = true
  min_tls_version           = "TLS1_2"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.storage.id]
  }

  customer_managed_key {
    key_vault_key_id          = azurerm_key_vault_key.storage.id
    user_assigned_identity_id = azurerm_user_assigned_identity.storage.id
  }

  tags = local.common_tags
}
```

### Network Security

```hcl
resource "azurerm_network_security_group" "web" {
  name                = "nsg-${local.name_prefix}-web"
  resource_group_name = var.resource_group_name
  location            = var.location

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}
```

## Resource Tagging

```hcl
locals {
  common_tags = {
    environment  = var.environment      # dev, staging, prod
    managed_by   = "terraform"
    owner        = var.team_name
    cost_center  = var.cost_center
    application  = var.application_name
    repository   = var.repo_url
  }
}

# Per-resource merge for additional context
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = merge(local.common_tags, { purpose = "application" })
}
```

Enforce required tags using `validation` blocks in variables and OPA/Sentinel policies in CI/CD.

## Cost Optimization

```hcl
# Storage tiering for cost savings
resource "azurerm_storage_management_policy" "data" {
  storage_account_id = azurerm_storage_account.data.id

  rule {
    name    = "lifecycle-tiering"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 30
        tier_to_archive_after_days_since_modification_greater_than = 90
        delete_after_days_since_modification_greater_than          = 365
      }
    }
  }
}

# Auto-scaling schedule to reduce costs outside business hours
resource "azurerm_monitor_autoscale_setting" "app" {
  name                = "autoscale-${local.name_prefix}-app"
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.app.id

  profile {
    name = "business-hours"

    capacity {
      default = 3
      minimum = 2
      maximum = 10
    }

    recurrence {
      timezone = "GMT Standard Time"
      days     = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
      hours    = [7]
      minutes  = [0]
    }
  }

  profile {
    name = "evenings-weekends"

    capacity {
      default = 1
      minimum = 1
      maximum = 2
    }

    recurrence {
      timezone = "GMT Standard Time"
      days     = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
      hours    = [20]
      minutes  = [0]
    }
  }
}
```

Integrate **Infracost** in CI/CD to show cost estimates on every PR before apply.

## Anti-Patterns

| Anti-Pattern | Problem | Correct Practice |
|---|---|---|
| Local state | Lost on disk; no locking; team collision | Azure Blob remote backend |
| `terraform.tfstate` in Git | Security exposure; merge conflicts | Remote backend; add to `.gitignore` |
| Workspaces for prod/staging/dev | Shared backend access; access control leakage | Separate backends per environment |
| Monolithic `main.tf` | Slow plans; large blast radius | Split by layer and concern |
| Providers/backends in child modules | Non-reusable; prevents multi-subscription use | Providers only in root modules |
| `count` for multi-instance resources | Unwanted destroys on list reordering | `for_each` with string keys |
| Secrets in `.tfvars` committed to VCS | Credential exposure | Env vars or Key Vault + ephemeral resources |
| Secrets in outputs without `sensitive` | Leaks in logs and plan output | Mark sensitive; use ephemeral resources (1.10+) |
| Exact version pinning in shared modules | Prevents consumer upgrades | Minimum constraints in modules |
| `terraform apply -target` in production | Incomplete state; false confidence | Full apply; use state splitting |
| No provider version constraints | Silent breaking upgrades | Pin with `~>` in root modules |
| `depends_on` on entire modules | Serializes all resources in both modules | Resource-level dependencies |
| Nested modules > 2 levels deep | Hard to debug and understand | Flat module structure |
| `any` type for variables | No validation; unclear contracts | Always use explicit types |
| Ignoring drift | Configuration rot; security gaps | Scheduled drift detection in CI/CD |
