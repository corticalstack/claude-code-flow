# Terraform Testing Strategies

Sources: [HashiCorp Tests Documentation](https://developer.hashicorp.com/terraform/language/tests), [Google Cloud Testing Best Practices](https://docs.cloud.google.com/docs/terraform/best-practices/testing)

## Testing Pyramid

| Level | Tool(s) | Cost | Speed | Confidence |
|-------|---------|------|-------|------------|
| Static analysis | `terraform fmt`, `terraform validate`, `tflint` | Free | Instant | Medium |
| Security scanning | Checkov, tfsec, Trivy | Free | Fast | Medium |
| Policy-as-code | OPA/Conftest, Sentinel | Free/paid | Fast | Medium |
| Unit / mock tests | `terraform test` + `mock_provider` (1.7+) | Free | Fast | Medium |
| Integration tests | `terraform test` (real resources) | Cloud costs | Slow | High |
| End-to-end tests | Terratest | High cloud costs | Very slow | Highest |

Start with static analysis as a blocking gate; add security scanning, policy checks, then integration tests. Do not skip to E2E before establishing the lower layers.

**CI gate order**: `fmt` → `validate` → `tflint` → `checkov` → `conftest` → `plan` → (human review) → `apply`

## Static Analysis

```bash
# Required before every commit
terraform fmt -check -recursive
terraform validate

# Initialize tflint plugins
tflint --init

# Run linter
tflint --recursive --config=.tflint.hcl
```

**.tflint.hcl**
```hcl
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "azurerm" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}
```

## Native `terraform test` Framework (Terraform 1.6+)

Test files use `.tftest.hcl` extension and live in a `tests/` directory:

```
module/
├── main.tf
├── variables.tf
├── outputs.tf
└── tests/
    ├── setup/
    │   └── main.tf        # Setup module — creates prerequisites
    ├── unit.tftest.hcl    # Plan-only tests with mock_provider
    └── integration.tftest.hcl   # Apply tests with real resources
```

### Unit Tests with Mock Provider (Terraform 1.7+)

Mock providers generate synthetic computed attributes without real API calls. Use for fast, credential-free unit testing:

```hcl
# tests/unit.tftest.hcl
mock_provider "azurerm" {
  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000/resourceGroups/test-rg"
    }
  }

  mock_resource "azurerm_storage_account" {
    defaults = {
      id                   = "/subscriptions/00000000/resourceGroups/test-rg/providers/Microsoft.Storage/storageAccounts/sttest"
      primary_blob_endpoint = "https://sttest.blob.core.windows.net/"
      primary_access_key   = "mockkey=="
    }
  }
}

run "valid_storage_name_accepted" {
  command = plan

  variables {
    name                = "stmytestaccount"
    resource_group_name = "test-rg"
    location            = "uksouth"
  }

  assert {
    condition     = azurerm_storage_account.this.name == "stmytestaccount"
    error_message = "Storage account name should match input variable."
  }

  assert {
    condition     = azurerm_storage_account.this.min_tls_version == "TLS1_2"
    error_message = "Storage account must enforce TLS 1.2 minimum."
  }
}

run "invalid_storage_name_rejected" {
  command = plan

  variables {
    name                = "Invalid Name!"   # Contains uppercase and special chars
    resource_group_name = "test-rg"
    location            = "uksouth"
  }

  # Expect the validation block to fail
  expect_failures = [var.name]
}

run "premium_in_dev_rejected" {
  command = plan

  variables {
    name                = "sttest"
    resource_group_name = "test-rg"
    location            = "uksouth"
    account_tier        = "Premium"
    environment         = "development"
  }

  expect_failures = [var.account_tier]
}
```

### Integration Tests with Real Resources

```hcl
# tests/integration.tftest.hcl
run "setup_resource_group" {
  command = apply

  module {
    source = "./tests/setup"
  }

  variables {
    location = "uksouth"
  }
}

run "create_storage_account" {
  command = apply

  variables {
    name                = "stintegrationtest${run.setup_resource_group.suffix}"
    resource_group_name = run.setup_resource_group.resource_group_name
    location            = "uksouth"
  }

  assert {
    condition     = output.storage_account_id != ""
    error_message = "Storage account ID should not be empty."
  }

  assert {
    condition     = azurerm_storage_account.this.enable_https_traffic_only == true
    error_message = "HTTPS traffic only must be enabled."
  }

  assert {
    condition     = azurerm_storage_account.this.min_tls_version == "TLS1_2"
    error_message = "Minimum TLS version must be TLS1_2."
  }
}
```

### Run Tests

```bash
# Run all tests
terraform test

# Run specific test file
terraform test tests/unit.tftest.hcl

# Verbose output (shows all assertions)
terraform test -verbose

# Keep test resources (for debugging — use sparingly)
terraform test -no-cleanup
```

## `check` Blocks (Terraform 1.5+)

`check` blocks run post-deployment assertions. Unlike `precondition`/`postcondition`, they produce **warnings** rather than errors and never block an apply:

```hcl
# Verify storage account is accessible after deployment
check "storage_account_accessible" {
  data "azurerm_storage_account" "verify" {
    name                = azurerm_storage_account.this.name
    resource_group_name = var.resource_group_name
  }

  assert {
    condition     = data.azurerm_storage_account.verify.enable_https_traffic_only == true
    error_message = "WARNING: Storage account ${azurerm_storage_account.this.name} does not enforce HTTPS. Remediate immediately."
  }
}

# Verify Key Vault is not publicly accessible
check "key_vault_network_restricted" {
  data "azurerm_key_vault" "verify" {
    name                = azurerm_key_vault.main.name
    resource_group_name = var.resource_group_name
  }

  assert {
    condition     = data.azurerm_key_vault.verify.network_acls[0].default_action == "Deny"
    error_message = "WARNING: Key Vault ${azurerm_key_vault.main.name} has public network access. Review network ACLs."
  }
}
```

Use `check` blocks for:
- Post-deployment health assertions (resource is reachable, config is correct)
- Drift warnings (real state diverged from expected)
- Advisory warnings that should not block deployment

Use `precondition`/`postcondition` (hard-fail) for:
- Pre-flight validation of provider-managed values
- Post-apply assertions critical enough to fail the apply

## Pre-commit Hooks

**.pre-commit-config.yaml**
```yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.96.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
        args:
          - --args=--config=__GIT_WORKING_DIR__/.tflint.hcl
      - id: terraform_docs
        args:
          - --hook-config=--path-to-file=README.md
          - --hook-config=--add-to-existing-file=true
      - id: terraform_checkov
        args:
          - --args=--quiet
          - --args=--framework terraform
```

```bash
pip install pre-commit
pre-commit install
pre-commit run -a   # Run manually against all files
```

## Policy as Code

### OPA/Conftest

```rego
# policies/required_tags.rego
package terraform.analysis

import input as tfplan

required_tags := ["environment", "managed_by", "owner", "cost_center"]

deny[msg] {
  resource := tfplan.resource_changes[_]
  resource.change.actions[_] == "create"
  tag_key := required_tags[_]
  not resource.change.after.tags[tag_key]
  msg := sprintf(
    "Resource %s is missing required tag: %s",
    [resource.address, tag_key]
  )
}

deny[msg] {
  resource := tfplan.resource_changes[_]
  resource.type == "azurerm_storage_account"
  resource.change.actions[_] == "create"
  resource.change.after.min_tls_version != "TLS1_2"
  msg := sprintf(
    "Storage account %s must enforce TLS1_2 minimum",
    [resource.address]
  )
}
```

```bash
# Generate plan JSON and run policy check
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json
conftest test tfplan.json --namespace terraform.analysis
```

### Checkov

```bash
# Run against Terraform HCL directly (no plan needed)
checkov -d . --framework terraform

# Run specific checks
checkov -d . --check CKV_AZURE_3,CKV_AZURE_59

# Skip specific checks with justification
checkov -d . --skip-check CKV_AZURE_50   # Managed by policy

# Output as SARIF for GitHub Code Scanning
checkov -d . --output sarif --output-file checkov.sarif
```

## Terratest vs `terraform test`

| Dimension | `terraform test` | Terratest |
|-----------|-----------------|-----------|
| Language | HCL | Go |
| Learning curve | Low | High |
| Mock support | Yes (1.7+) | No native mocks |
| Best for | Module unit + integration tests | Complex multi-module E2E |
| Parallelism | `parallel = true` flag | `t.Parallel()` |
| Maintenance burden | Lower | Higher |

**Recommendation**: Use `terraform test` as the default. Reach for Terratest only for complex multi-module scenarios requiring programmatic control flow (conditional logic, retry loops, external API verification).

## CI/CD Pipeline

### GitHub Actions

```yaml
name: Terraform CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

# Serialize applies per environment — never cancel an in-flight apply
concurrency:
  group: terraform-production-${{ github.ref }}
  cancel-in-progress: false

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~> 1.10"

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Terraform Init
        env:
          ARM_USE_OIDC: "true"
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
        run: terraform init -backend-config=envs/prod.backend.hcl

      - name: Terraform Validate
        run: terraform validate

      - name: TFLint
        uses: terraform-linters/setup-tflint@v4
        with:
          tflint_version: latest
      - run: tflint --recursive

      - name: Checkov
        uses: bridgecrewio/checkov-action@master
        with:
          directory: .
          framework: terraform
          output_format: sarif
          output_file_path: checkov.sarif

  plan:
    needs: validate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~> 1.10"

      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Terraform Init
        env:
          ARM_USE_OIDC: "true"
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
        run: terraform init -backend-config=envs/prod.backend.hcl

      - name: Terraform Plan
        id: plan
        env:
          ARM_USE_OIDC: "true"
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
        run: terraform plan -out=tfplan -var-file=envs/prod.tfvars

      # Post plan as PR comment
      - uses: actions/github-script@v7
        with:
          script: |
            const output = `#### Plan Result\n\`\`\`\n${{ steps.plan.outputs.stdout }}\n\`\`\``;
            github.rest.issues.createComment({ issue_number: context.issue.number, owner: context.repo.owner, repo: context.repo.repo, body: output });

      - name: Upload Plan
        uses: actions/upload-artifact@v4
        with:
          name: tfplan
          path: tfplan
          retention-days: 1   # Never apply plans older than this

  apply:
    needs: plan
    runs-on: ubuntu-latest
    environment: production   # Requires GitHub Environment approval
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~> 1.10"

      - uses: actions/download-artifact@v4
        with:
          name: tfplan

      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Terraform Init
        env:
          ARM_USE_OIDC: "true"
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
        run: terraform init -backend-config=envs/prod.backend.hcl

      - name: Terraform Apply
        env:
          ARM_USE_OIDC: "true"
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
        run: terraform apply tfplan

### Drift Detection (Scheduled)

```yaml
name: Drift Detection

on:
  schedule:
    - cron: "0 8 * * 1-5"   # Weekdays at 08:00 UTC

jobs:
  detect-drift:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Terraform Init
        env:
          ARM_USE_OIDC: "true"
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
        run: terraform init -backend-config=envs/prod.backend.hcl

      - name: Check for Drift
        id: drift
        env:
          ARM_USE_OIDC: "true"
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
        run: |
          terraform plan -detailed-exitcode -var-file=envs/prod.tfvars
          echo "exit_code=$?" >> $GITHUB_OUTPUT
        continue-on-error: true

      # Exit code 2 = changes detected (drift)
      - name: Open Drift Issue
        if: steps.drift.outputs.exit_code == '2'
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: "Infrastructure drift detected in production",
              body: "Terraform plan detected drift. Review and remediate: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}",
              labels: ["infrastructure", "drift"]
            });
```

## Best Practices

- Use `terraform test` with `mock_provider` for fast credential-free unit tests
- Use `check` blocks for post-deployment health assertions (warnings, never blocking)
- Run `terraform fmt -check` as the first blocking CI gate
- Run Checkov and tfsec before `terraform plan` — static analysis is faster and cheaper
- Use GitHub Environments with required reviewers for production `apply` approval
- Serialize environment deploys with `concurrency` (no parallel applies to the same env)
- Never apply plans older than 6 hours (use `retention-days: 1` on plan artifacts)
- Run scheduled drift detection and auto-open issues when drift is found
- Use OIDC authentication in CI/CD — no long-lived credentials stored in secrets
- Integrate Infracost for cost estimates on every PR
