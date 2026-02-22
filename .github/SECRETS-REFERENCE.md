# GitHub Repository Secrets & OIDC Configuration

Quick reference card for required GitHub secrets and Azure OIDC federated credentials configuration.

## Required GitHub Secrets

Configure these in: **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

| Secret Name | Description | Example Value | Where to Find |
|-------------|-------------|---------------|---------------|
| `AZURE_CLIENT_ID` | Application (client) ID | `12345678-1234-1234-1234-123456789abc` | Azure Portal → App Registrations → [Your App] → Overview → Application (client) ID |
| `AZURE_TENANT_ID` | Azure AD tenant ID | `87654321-4321-4321-4321-abcdefabcdef` | Azure Portal → Microsoft Entra ID → Overview → Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | `abcdefab-cdef-abcd-efab-abcdefabcdef` | Azure Portal → Subscriptions → [Your Subscription] → Subscription ID |

### Commands to Get Values

```bash
# Get Application (client) ID
az ad app list --display-name "github-actions-webapp-demo" --query "[0].appId" -o tsv

# Get Tenant ID
az account show --query tenantId -o tsv

# Get Subscription ID (use your subscription ID variable)
echo $SUBSCRIPTION_ID
```

### Set Secrets Using GitHub CLI

```bash
gh secret set AZURE_CLIENT_ID --body "YOUR_APPLICATION_ID"
gh secret set AZURE_TENANT_ID --body "YOUR_TENANT_ID"
gh secret set AZURE_SUBSCRIPTION_ID --body "YOUR_SUBSCRIPTION_ID"
```

---

## Azure Federated Credentials Configuration

Configure these in: **Azure Portal** → **App Registrations** → [Your App] → **Certificates & secrets** → **Federated credentials**

### Configuration Table

| Credential Name | Issuer | Subject | Audience | Purpose |
|-----------------|--------|---------|----------|---------|
| `github-main-branch` | `https://token.actions.githubusercontent.com` | `repo:ORG/REPO:ref:refs/heads/main` | `api://AzureADTokenExchange` | Production deployments |
| `github-dev-branch` | `https://token.actions.githubusercontent.com` | `repo:ORG/REPO:ref:refs/heads/dev` | `api://AzureADTokenExchange` | Dev deployments |
| `github-qa-branch` | `https://token.actions.githubusercontent.com` | `repo:ORG/REPO:ref:refs/heads/qa` | `api://AzureADTokenExchange` | QA deployments |
| `github-pull-requests` | `https://token.actions.githubusercontent.com` | `repo:ORG/REPO:pull_request` | `api://AzureADTokenExchange` | PR validation |

**Important**: Replace `ORG/REPO` with your actual GitHub organization and repository name.

Example: `repo:BenTheCloudGuy/msftlabs-bicep-webapp-demo:ref:refs/heads/main`

### Create Using Azure CLI

```bash
# Variables (UPDATE THESE)
GITHUB_ORG="YOUR_GITHUB_ORG"        # Example: "BenTheCloudGuy"
REPO_NAME="YOUR_REPO_NAME"          # Example: "msftlabs-bicep-webapp-demo"
APP_NAME="github-actions-webapp-demo"

# Get Application Object ID
APP_OBJECT_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].id" -o tsv)

# Create federated credential for main branch
az ad app federated-credential create \
  --id $APP_OBJECT_ID \
  --parameters "{
    \"name\": \"github-main-branch\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:$GITHUB_ORG/$REPO_NAME:ref:refs/heads/main\",
    \"description\": \"GitHub Actions - Main Branch (Production)\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

# Create federated credential for dev branch
az ad app federated-credential create \
  --id $APP_OBJECT_ID \
  --parameters "{
    \"name\": \"github-dev-branch\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:$GITHUB_ORG/$REPO_NAME:ref:refs/heads/dev\",
    \"description\": \"GitHub Actions - Dev Branch\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

# Create federated credential for qa branch
az ad app federated-credential create \
  --id $APP_OBJECT_ID \
  --parameters "{
    \"name\": \"github-qa-branch\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:$GITHUB_ORG/$REPO_NAME:ref:refs/heads/qa\",
    \"description\": \"GitHub Actions - QA Branch\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

# Create federated credential for pull requests
az ad app federated-credential create \
  --id $APP_OBJECT_ID \
  --parameters "{
    \"name\": \"github-pull-requests\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:$GITHUB_ORG/$REPO_NAME:pull_request\",
    \"description\": \"GitHub Actions - Pull Requests\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"
```

---

## Required Azure Role Assignments

Configure these in: **Azure Portal** → **Subscriptions** → [Your Subscription] → **Access control (IAM)**

| Role | Scope | Required | Purpose |
|------|-------|----------|---------|
| `Contributor` | Subscription | ✅ Yes | Deploy and manage Azure resources |
| `User Access Administrator` | Subscription | Optional | Assign RBAC roles to resources |
| `Resource Policy Contributor` | Subscription | Optional | Assign Azure Policy definitions |

### Assign Using Azure CLI

```bash
# Get Application ID
APP_ID=$(az ad app list --display-name "github-actions-webapp-demo" --query "[0].appId" -o tsv)

# Assign Contributor role (required)
az role assignment create \
  --assignee $APP_ID \
  --role "Contributor" \
  --scope "/subscriptions/YOUR_SUBSCRIPTION_ID"

# Assign User Access Administrator role (optional)
az role assignment create \
  --assignee $APP_ID \
  --role "User Access Administrator" \
  --scope "/subscriptions/YOUR_SUBSCRIPTION_ID"
```

---

## Workflow Configuration Requirements

All workflows must include these permissions in their YAML files:

```yaml
permissions:
  id-token: write    # Required for OIDC authentication
  contents: read     # Required to checkout repository code
```

And use this Azure login step:

```yaml
- name: Azure Login
  uses: azure/login@v1
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

---

## Verification Commands

### Verify Azure Configuration

```bash
# Set variables
APP_NAME="github-actions-webapp-demo"
APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
APP_OBJECT_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].id" -o tsv)

# Check app registration exists
echo "Application ID: $APP_ID"

# List role assignments
echo ""
echo "Role Assignments:"
az role assignment list --assignee $APP_ID --output table

# List federated credentials
echo ""
echo "Federated Credentials:"
az ad app federated-credential list --id $APP_OBJECT_ID --output table
```

### Verify GitHub Configuration

```bash
# List GitHub secrets
gh secret list

# Expected output:
# AZURE_CLIENT_ID        Updated YYYY-MM-DD
# AZURE_SUBSCRIPTION_ID  Updated YYYY-MM-DD
# AZURE_TENANT_ID        Updated YYYY-MM-DD
```

---

## Quick Reference Summary

### ✅ Checklist

- [ ] Azure App Registration created
- [ ] Contributor role assigned at subscription level
- [ ] 4 federated credentials created (main, dev, qa, pull_request)
- [ ] 3 GitHub secrets configured (CLIENT_ID, TENANT_ID, SUBSCRIPTION_ID)
- [ ] Workflow files have `id-token: write` permission
- [ ] Azure login uses correct secrets
- [ ] Branches created (main, dev, qa)

### 📚 Documentation Links

- [Quick Start Guide](../QUICKSTART.md) - Fast setup (10 minutes)
- [Detailed Setup Guide](../SETUP.md) - Step-by-step instructions
- [OIDC Authentication Guide](OIDC-AUTHENTICATION.md) - How it works
- [Setup Checklist](../SETUP-CHECKLIST.md) - Verify configuration

### 🆘 Troubleshooting

**Authentication fails?**
- Verify federated credential subject matches repository exactly
- Check GitHub secrets have no typos
- Ensure branch names in subject match actual branch names

**Permission denied?**
- Verify Contributor role is assigned
- Check service principal is not disabled
- Confirm subscription ID is correct

**Workflow doesn't trigger?**
- Verify branch name matches workflow trigger
- Check workflow files are in `.github/workflows/`
- Ensure Actions are enabled in repository settings

---

## Additional Resources

- [Microsoft Learn: Connect GitHub and Azure](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure)
- [GitHub Docs: OpenID Connect](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [Azure AD: Workload Identity Federation](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation)
- [GitHub Actions: Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
