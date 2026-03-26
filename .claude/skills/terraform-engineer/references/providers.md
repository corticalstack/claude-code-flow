# Terraform Provider Configuration

## Azure Provider (azurerm)

### Basic Configuration

```hcl
# versions.tf
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"   # Root module: pin with ~>; shared modules: use >= minimum
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}

# providers.tf
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }

    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }

    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
    }
  }

  subscription_id = var.subscription_id
}
```

### Version Pinning — Root vs Shared Modules

```hcl
# Root module — use pessimistic constraint (~>) to allow patch updates
# but prevent unexpected major/minor upgrades
required_providers {
  azurerm = {
    source  = "hashicorp/azurerm"
    version = "~> 4.1"   # Allows 4.1.x but not 5.x
  }
}

# Shared/reusable module — use minimum constraint only
# Callers choose the exact version; do not restrict their choice
required_providers {
  azurerm = {
    source  = "hashicorp/azurerm"
    version = ">= 4.0"
  }
}
```

**Always commit `.terraform.lock.hcl`** — pins exact provider checksums for reproducibility across all machines and CI runs. Never add it to `.gitignore`.

### Azure Authentication Methods

```hcl
# Method 1: Azure CLI (local development only)
provider "azurerm" {
  features {}
  use_cli         = true
  subscription_id = var.subscription_id
}

# Method 2: Service Principal with Client Secret (avoid for production)
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret   # Prefer env: ARM_CLIENT_SECRET
}

# Method 3: Service Principal with Client Certificate
provider "azurerm" {
  features {}
  subscription_id             = var.subscription_id
  tenant_id                   = var.tenant_id
  client_id                   = var.client_id
  client_certificate_path     = var.certificate_path
  client_certificate_password = var.certificate_password
}

# Method 4: Managed Identity (preferred for Azure-hosted runners/VMs)
provider "azurerm" {
  features {}
  use_msi         = true
  subscription_id = var.subscription_id
}

# Method 5: OIDC / Workload Identity Federation (preferred for CI/CD)
# No long-lived credentials — GitHub Actions, Azure DevOps, etc. exchange
# OIDC tokens for short-lived Azure AD tokens
provider "azurerm" {
  features {}
  use_oidc        = true
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
}
```

### OIDC Setup for GitHub Actions

```yaml
# GitHub Actions workflow — no long-lived credentials
- uses: azure/login@v2
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

- name: Terraform Apply
  env:
    ARM_USE_OIDC: "true"
    ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
    ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
    ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
  run: terraform apply -auto-approve tfplan
```

Terraform ARM_ environment variables (used for all auth methods):

| Variable | Description |
|----------|-------------|
| `ARM_SUBSCRIPTION_ID` | Azure subscription ID |
| `ARM_TENANT_ID` | Azure AD tenant ID |
| `ARM_CLIENT_ID` | Service principal / managed identity client ID |
| `ARM_CLIENT_SECRET` | Service principal secret (avoid in production) |
| `ARM_USE_OIDC` | Set to `true` for OIDC authentication |
| `ARM_USE_MSI` | Set to `true` for Managed Identity |

### Multiple Subscriptions / Provider Aliases

Use provider aliases when managing resources across multiple subscriptions or regions:

```hcl
# providers.tf
provider "azurerm" {
  alias           = "production"
  features        {}
  subscription_id = var.prod_subscription_id
  tenant_id       = var.tenant_id
}

provider "azurerm" {
  alias           = "shared-services"
  features        {}
  subscription_id = var.shared_subscription_id
  tenant_id       = var.tenant_id
}

# Pass aliases explicitly to modules — never rely on inheritance for aliased providers
module "prod_resources" {
  source = "./modules/app"
  providers = {
    azurerm = azurerm.production
  }
}

# Use alias directly on resources
resource "azurerm_resource_group" "shared" {
  provider = azurerm.shared-services
  name     = "rg-shared-services"
  location = var.location
}
```

### Multi-Region Deployment Pattern

```hcl
provider "azurerm" {
  alias           = "primary"
  features        {}
  subscription_id = var.subscription_id
}

provider "azurerm" {
  alias           = "secondary"
  features        {}
  subscription_id = var.subscription_id
}

# Primary region resources
module "app_primary" {
  source   = "./modules/app"
  location = "uksouth"

  providers = {
    azurerm = azurerm.primary
  }
}

# Secondary region for disaster recovery
module "app_secondary" {
  source   = "./modules/app"
  location = "ukwest"

  providers = {
    azurerm = azurerm.secondary
  }
}
```

## Kubernetes Provider (with AKS)

```hcl
data "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  resource_group_name = var.resource_group_name
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.aks.kube_config[0].host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
}
```

## Helm Provider

```hcl
provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.aks.kube_config[0].host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
  }
}

resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.10.0"
  namespace  = "ingress-nginx"

  create_namespace = true

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz"
  }
}
```

## Additional Providers

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}
```

## Best Practices

- **Root modules**: pin with `~>` (pessimistic constraint) to allow patch updates
- **Shared modules**: use `>=` minimum only — do not restrict caller's version choice
- **Commit `.terraform.lock.hcl`** — ensures reproducible provider checksums across all environments
- Use **OIDC/Workload Identity** in CI/CD — eliminates long-lived credential rotation entirely
- Use **Managed Identity** for Azure-hosted compute (VMs, AKS nodes, Azure DevOps agents)
- Use **Azure CLI** for local development only; never in CI/CD pipelines
- Supply credentials via environment variables (`ARM_*`) — never hardcode in provider blocks
- Use provider **aliases** for multi-subscription/multi-region deployments; always pass aliases explicitly via `providers` map in module blocks
- Test provider upgrades in non-production environments before rolling to production
- Document provider requirements in module `README.md`
