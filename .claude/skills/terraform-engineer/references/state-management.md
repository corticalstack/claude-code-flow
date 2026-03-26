# Terraform State Management

## Backend Selection

| Context | Backend | Notes |
|---------|---------|-------|
| Team / CI/CD / production | `azurerm` (Azure Blob) | Remote state, locking, encryption |
| Local development / testing | `local` or `-backend=false` | No locking; never commit state file |

### Disable Backend for Local Testing

Use `-backend=false` to skip remote state entirely when iterating locally. Terraform falls back to a local `terraform.tfstate` file:

```bash
terraform init -backend=false
terraform plan -var-file=envs/dev.tfvars
```

Or use the `local` backend explicitly in a dev override file (never commit this):

```hcl
# backend-local.hcl  (add to .gitignore)
path = "terraform.tfstate.local"
```

```bash
terraform init -backend-config=backend-local.hcl
```

Add to `.gitignore`:
```
*.tfstate
*.tfstate.*
*.tfstate.local
.terraform/
```

## Remote Backend — Azure Blob Storage (Team / CI/CD)

Azure Blob Storage is the standard remote backend. It provides native state locking (no separate resource required) and automatic server-side encryption.

### Backend Configuration

```hcl
# backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "storgterraformstate"
    container_name       = "tfstate"
    key                  = "production/myapp/terraform.tfstate"
    use_azuread_auth     = true   # Use Azure AD auth instead of storage key
  }
}
```

### Azure Storage Setup for State

```hcl
# Bootstrap — create state storage separately (use local state temporarily, then migrate)
resource "azurerm_resource_group" "terraform_state" {
  name     = "rg-terraform-state"
  location = var.location

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    purpose    = "terraform-state"
    managed_by = "terraform"
  }
}

resource "azurerm_storage_account" "terraform_state" {
  name                      = "storgterraformstate"
  resource_group_name       = azurerm_resource_group.terraform_state.name
  location                  = azurerm_resource_group.terraform_state.location
  account_tier              = "Standard"
  account_replication_type  = "GRS"
  enable_https_traffic_only = true
  min_tls_version           = "TLS1_2"

  blob_properties {
    versioning_enabled = true   # Enable for rollback capability
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = azurerm_resource_group.terraform_state.tags
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.terraform_state.name
  container_access_type = "private"
}

# Restrict access to state — CI/CD service principal only
resource "azurerm_role_assignment" "terraform_state_contributor" {
  scope                = azurerm_storage_account.terraform_state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.cicd_service_principal_object_id
}
```

### Partial Backend Configuration

Supply environment-specific values at `terraform init` time to reuse a shared backend configuration:

```hcl
# backend.tf
terraform {
  backend "azurerm" {
    # Values provided via -backend-config or environment variables
  }
}
```

```hcl
# config/backend-prod.hcl
resource_group_name  = "rg-terraform-state-prod"
storage_account_name = "stterraformstateprod"
container_name       = "tfstate"
key                  = "myapp/terraform.tfstate"
use_azuread_auth     = true
```

```bash
terraform init -backend-config=config/backend-prod.hcl
```

## Environment Isolation Strategy

Use **separate backends per environment** — the strongest isolation model:

| Approach | Isolation | Access Control | Recommended? |
|----------|-----------|----------------|--------------|
| Separate backends (separate storage accounts) | Strong | Per-environment IAM | ✅ Yes |
| Same backend, different keys | Weak | Shared access | ⚠️ Only for small teams |
| Workspaces | Weak | Shared backend access | ❌ Not for prod/staging/dev |

```
# Separate state storage per environment
envs/
├── dev/
│   └── backend.hcl   → storage account: stterraformstatedev
├── staging/
│   └── backend.hcl   → storage account: stterraformstatestg
└── prod/
    └── backend.hcl   → storage account: stterraformstateprod
```

Limit write access to production state to the CI/CD pipeline and break-glass roles only.

## Workspaces — When to Use

### Appropriate Uses

- Ephemeral feature-branch environments
- Short-lived testing of configuration variations
- Tenant separation within a single identical topology

### NOT Appropriate For

- Separating dev/staging/production (use separate backends)
- Teams with different access requirements per environment
- Configurations with significant per-environment differences

```hcl
# Workspace-aware configuration (only for same-topology multi-tenant use case)
locals {
  environment = terraform.workspace

  vm_size = {
    production  = "Standard_D4s_v3"
    staging     = "Standard_D2s_v3"
    development = "Standard_B2ms"
  }
}
```

```bash
terraform workspace list
terraform workspace new feature-xyz
terraform workspace select production
terraform workspace show
terraform workspace delete feature-xyz
```

## State Splitting

Split large monolithic state into smaller focused states organized by layer. Organizations report **70–90% reduction in plan/apply times**.

Split criteria:
- **Blast radius**: network changes are more dangerous than app config changes
- **Change frequency**: foundational infra changes rarely; app config changes often
- **Team ownership**: different teams own different layers
- **Lifecycle**: long-lived shared infra vs. ephemeral app deployments

```
# Recommended layer structure
├── networking/      → VNet, subnets, NSGs, peerings
├── identity/        → Managed identities, role assignments, Key Vault
├── data/            → Storage accounts, SQL servers, Redis
├── platform/        → AKS, App Service plans, Container Registry
└── applications/    → App deployments, app settings, app role assignments
```

Share outputs across state boundaries using `terraform_remote_state`:

```hcl
# In applications/main.tf — consume networking outputs
data "terraform_remote_state" "networking" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate"
    container_name       = "tfstate"
    key                  = "networking/terraform.tfstate"
    use_azuread_auth     = true
  }
}

resource "azurerm_linux_web_app" "app" {
  name                = "app-${local.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = azurerm_service_plan.main.id

  site_config {
    vnet_route_all_enabled = true
  }

  virtual_network_subnet_id = data.terraform_remote_state.networking.outputs.app_subnet_id
}
```

## State Operations

### Import Existing Resources

Prefer `import` blocks (reviewable, version-controlled) over CLI `terraform import`:

```hcl
# import block (Terraform 1.5+)
import {
  to = azurerm_resource_group.main
  id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-existing"
}

# Generate configuration automatically (plan then copy)
terraform plan -generate-config-out=generated.tf
```

### State Manipulation Commands

```bash
# List resources in state
terraform state list

# Show resource details
terraform state show azurerm_resource_group.main

# Move resource in state (prefer moved block in .tf files instead)
terraform state mv azurerm_storage_account.old azurerm_storage_account.new

# Remove resource from state without destroying (prefer removed block instead)
terraform state rm azurerm_storage_account.legacy

# Pull remote state to local backup
terraform state pull > backup.tfstate

# Refresh state (reconcile with real resources)
terraform plan -refresh-only
terraform apply -refresh-only
```

### State Migration

```bash
# Migrate from local to remote backend
terraform init -migrate-state

# Reconfigure backend (non-migrating change)
terraform init -reconfigure

# Move state to a new backend configuration
terraform init -backend-config=new-backend.hcl -migrate-state
```

## State Locking

State locking happens automatically with Azure Blob Storage — no extra configuration required.

```bash
# Force unlock if lock is stuck (use with caution — verify no apply is running)
terraform force-unlock LOCK_ID

# Never disable locking in production
terraform apply -lock=false   # DO NOT USE IN PRODUCTION
```

## State Security

```hcl
# State storage access control — restrict to CI/CD only
resource "azurerm_role_assignment" "cicd_state_access" {
  scope                = azurerm_storage_account.terraform_state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.cicd_service_principal_object_id
}

# Deny public access
resource "azurerm_storage_account" "terraform_state" {
  # ... (see Setup section above)

  # Require Microsoft Entra ID (Azure AD) auth — disable storage key auth
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = var.allowed_cicd_ips
  }
}
```

```
# Recommended state file organization per environment
myapp-tfstate-prod/
└── tfstate/
    ├── networking/terraform.tfstate
    ├── identity/terraform.tfstate
    ├── data/terraform.tfstate
    └── applications/terraform.tfstate
```

## Best Practices

- Always use remote state for team environments
- Use Azure Blob Storage for Azure workloads — native locking, no extra setup
- Enable blob versioning for rollback capability
- Use separate state storage accounts per environment (dev/staging/prod)
- Restrict state access to CI/CD pipeline and break-glass roles only
- Enable audit logging (Azure Monitor) on state storage for attribution
- Never commit state files to Git
- Never disable state locking (`-lock=false`) in team or production environments
- Use `import` blocks (plannable, reviewable) over CLI `terraform import`
- Use `removed` blocks over `terraform state rm` for planned state removal
- Use `moved` blocks over `terraform state mv` when refactoring
- Split large monolithic state by layer and ownership
- Use `terraform_remote_state` with read-only role assignments to share outputs across stacks
