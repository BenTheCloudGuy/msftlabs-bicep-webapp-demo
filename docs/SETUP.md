# GitHub WebApp Demo - Setup Guide

This guide will walk you through setting up the CI/CD demo from scratch.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Reference](#quick-reference)
3. [Azure Setup](#azure-setup)
4. [GitHub Setup](#github-setup)
5. [Initial Deployment](#initial-deployment)
6. [Testing](#testing)
7. [Troubleshooting](#troubleshooting)

---

## Quick Reference

### Required GitHub Repository Secrets

| Secret Name | Description | Where to Find |
|-------------|-------------|---------------|
| `AZURE_CLIENT_ID` | Application (client) ID | Azure Portal → App Registrations → Your App → Overview |
| `AZURE_TENANT_ID` | Azure AD tenant ID | Azure Portal → Tenant Properties → Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | Azure Portal → Subscriptions → Your Subscription |

### Required Azure Federated Credentials

Configure these in Azure App Registration → Certificates & secrets → Federated credentials:

| Name | Subject | Audience | Purpose |
|------|---------|----------|---------|
| `github-main-branch` | `repo:ORG/REPO:ref:refs/heads/main` | `api://AzureADTokenExchange` | Production deployments |
| `github-dev-branch` | `repo:ORG/REPO:ref:refs/heads/dev` | `api://AzureADTokenExchange` | Dev deployments |
| `github-qa-branch` | `repo:ORG/REPO:ref:refs/heads/qa` | `api://AzureADTokenExchange` | QA deployments |
| `github-pull-requests` | `repo:ORG/REPO:pull_request` | `api://AzureADTokenExchange` | PR validation |

**Important**: Replace `ORG/REPO` with your GitHub organization and repository name (e.g., `BenTheCloudGuy/msftlabs-bicep-webapp-demo`).

### Key Commands

```bash
# Quick setup
az login
APP_ID=$(az ad app list --display-name "github-actions-webapp-demo" --query "[0].appId" -o tsv)
gh secret set AZURE_CLIENT_ID --body "$APP_ID"
gh secret set AZURE_TENANT_ID --body "$(az account show --query tenantId -o tsv)"
gh secret set AZURE_SUBSCRIPTION_ID --body "YOUR_SUBSCRIPTION_ID"

# Verify configuration
gh secret list
az ad app federated-credential list --id $(az ad app list --display-name "github-actions-webapp-demo" --query "[0].id" -o tsv) --output table
```

---

## Prerequisites

Before you begin, ensure you have:

- Azure subscription with Owner or Contributor access
- GitHub account with repository access
- Azure CLI installed ([Download](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
- Bicep CLI installed (`az bicep install`)
- GitHub CLI installed (optional, [Download](https://cli.github.com/))
- PowerShell 7+ or Bash
- Node.js 18 LTS or higher

---

## Azure Setup

### Step 1: Login to Azure

```bash
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### Step 2: Create Application Registration and Configure OIDC

This demo uses OpenID Connect (OIDC) for secure, passwordless authentication between GitHub Actions and Azure. No secrets are stored, making it more secure than traditional service principals.

Learn more: [GitHub to Azure OIDC](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure)

#### A. Create Application Registration

```bash
# Store your subscription ID
SUBSCRIPTION_ID="YOUR_SUBSCRIPTION_ID"

# Create application registration
APP_NAME="github-actions-webapp-demo"
az ad app create --display-name "$APP_NAME"

# Get the Application (client) ID
APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
echo "Application ID: $APP_ID"

# Create service principal
az ad sp create --id $APP_ID

# Get the Service Principal Object ID
SP_OBJECT_ID=$(az ad sp list --display-name "$APP_NAME" --query "[0].id" -o tsv)
echo "Service Principal Object ID: $SP_OBJECT_ID"

# Assign Contributor role to subscription
az role assignment create \
  --assignee $APP_ID \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"
```

#### B. Configure Federated Credentials for GitHub Actions

Create federated credentials for each environment. These allow GitHub Actions workflows to authenticate without secrets.

**Replace `YOUR_GITHUB_ORG` and `YOUR_REPO_NAME` with your values.**

```bash
# Variables (UPDATE THESE)
GITHUB_ORG="YOUR_GITHUB_ORG"           # Example: "BenTheCloudGuy"
REPO_NAME="YOUR_REPO_NAME"             # Example: "msftlabs-bicep-webapp-demo"

# Get Application Object ID
APP_OBJECT_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].id" -o tsv)

# Create federated credential for main branch (production)
az ad app federated-credential create \
  --id $APP_OBJECT_ID \
  --parameters '{
    "name": "github-main-branch",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"$GITHUB_ORG/$REPO_NAME"':ref:refs/heads/main",
    "description": "GitHub Actions - Main Branch (Production)",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create federated credential for dev branch
az ad app federated-credential create \
  --id $APP_OBJECT_ID \
  --parameters '{
    "name": "github-dev-branch",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"$GITHUB_ORG/$REPO_NAME"':ref:refs/heads/dev",
    "description": "GitHub Actions - Dev Branch",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create federated credential for qa branch
az ad app federated-credential create \
  --id $APP_OBJECT_ID \
  --parameters '{
    "name": "github-qa-branch",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"$GITHUB_ORG/$REPO_NAME"':ref:refs/heads/qa",
    "description": "GitHub Actions - QA Branch",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create federated credential for pull requests (for validation)
az ad app federated-credential create \
  --id $APP_OBJECT_ID \
  --parameters '{
    "name": "github-pull-requests",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"$GITHUB_ORG/$REPO_NAME"':pull_request",
    "description": "GitHub Actions - Pull Requests",
    "audiences": ["api://AzureADTokenExchange"]
  }'

echo "Federated credentials created successfully!"
```

#### C. Get Azure Identity Information

**Save these values** - you'll need them for GitHub secrets:

```bash
# Display all required information
echo "==================================="
echo "GitHub Secrets Configuration"
echo "==================================="
echo "AZURE_CLIENT_ID: $APP_ID"
echo "AZURE_TENANT_ID: $(az account show --query tenantId -o tsv)"
echo "AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
echo "==================================="
```

### Step 3: Assign Additional Permissions (Optional)

If you plan to deploy resources that require elevated permissions (RBAC assignments, policy assignments, etc.):

```bash
# Grant User Access Administrator role (for RBAC assignments)
az role assignment create \
  --assignee $APP_ID \
  --role "User Access Administrator" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# Grant Resource Policy Contributor role (for policy assignments, optional)
az role assignment create \
  --assignee $APP_ID \
  --role "Resource Policy Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"
```

#### Verify Configuration

```bash
# List all role assignments
az role assignment list --assignee $APP_ID --output table

# List all federated credentials
az ad app federated-credential list --id $APP_OBJECT_ID --output table
```

---

## GitHub Setup

### Step 1: Fork or Clone the Repository

```bash
git clone https://github.com/BenTheCloudGuy/msftlabs-intro-to-bicep.git
cd msftlabs-intro-to-bicep
```

### Step 2: Create GitHub Environments

Go to your repository Settings → Environments and create three environments:

1. **development**
   - No protection rules required
   
2. **qa**
   - Required reviewers: Add yourself or team members
   - Wait timer: 5 minutes (optional)
   
3. **production**
   - Required reviewers: Add yourself or team members
   - Wait timer: 30 minutes (optional)
   - Branch protection: Only `main` branch

### Step 3: Configure GitHub Repository Secrets

GitHub Actions requires three secrets for OIDC authentication with Azure. No client secrets or passwords are stored, making this approach more secure.

Learn more: [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)

#### Required Secrets

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `AZURE_CLIENT_ID` | Application (client) ID from Step 2C | `12345678-1234-1234-1234-123456789abc` |
| `AZURE_TENANT_ID` | Azure AD (Entra ID) tenant ID | `87654321-4321-4321-4321-abcdef123456` |
| `AZURE_SUBSCRIPTION_ID` | Target Azure subscription ID | `abcdefab-cdef-abcd-efab-abcdefabcdef` |

#### Option A: Using GitHub CLI

```bash
# Set secrets using GitHub CLI (recommended)
gh secret set AZURE_CLIENT_ID --body "$APP_ID"
gh secret set AZURE_TENANT_ID --body "$(az account show --query tenantId -o tsv)"
gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID"

# Verify secrets were created
gh secret list
```

#### Option B: Using GitHub Web UI

1. Navigate to your repository on GitHub
2. Go to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret:
   - Name: `AZURE_CLIENT_ID`
     - Value: Your Application (client) ID
   - Name: `AZURE_TENANT_ID`
     - Value: Your Azure AD tenant ID
   - Name: `AZURE_SUBSCRIPTION_ID`
     - Value: Your Azure subscription ID

#### Verify Secrets Configuration

```bash
# List configured secrets (values are hidden)
gh secret list

# Output should show:
# AZURE_CLIENT_ID        Updated YYYY-MM-DD
# AZURE_SUBSCRIPTION_ID  Updated YYYY-MM-DD
# AZURE_TENANT_ID        Updated YYYY-MM-DD
```

#### How OIDC Authentication Works

When a GitHub Actions workflow runs:
1. GitHub generates a short-lived OIDC token for the workflow
2. The workflow exchanges this token with Azure AD
3. Azure AD validates the token against the federated credentials
4. Azure AD issues an Azure access token valid for the workflow duration
5. No secrets are stored or transmitted - only tokens with limited lifetime

This eliminates the need to manage and rotate client secrets.

### Step 4: Create Branches

```bash
# Create dev branch
git checkout -b dev
git push -u origin dev

# Create qa branch
git checkout -b qa
git push -u origin qa

# Return to main
git checkout main
```

---

## Initial Deployment

### Step 1: Update Parameter Files

Edit the parameter files to match your environment:

**demos/github-webapp-demo/parameters/prod.bicepparam**:
```bicep
param deployCommonMgmt = true  // First time only
param deployAppGateway = true
param deploySelfHostedRunner = true
param vmAdminPassword = 'YOUR_SECURE_PASSWORD'  // Change this!
```

**demos/github-webapp-demo/parameters/dev.bicepparam** and **qa.bicepparam**:
```bicep
param logAnalyticsWorkspaceId = '/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/rg-eastus-prod-mgmt-common/providers/Microsoft.OperationalInsights/workspaces/core-law'
```

### Step 2: Test Locally (Optional)

Validate the Bicep files locally:

```bash
cd demos/github-webapp-demo

# Lint Bicep files
bicep build bicep/main.bicep

# Run what-if analysis
az deployment sub what-if \
  --location eastus \
  --template-file bicep/main.bicep \
  --parameters parameters/dev.bicepparam \
  --parameters deployedBy="$USER" \
  --parameters deployedDate="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
```

### Step 3: Run Pester Tests (Optional on Windows)

```powershell
# Install Pester
Install-Module -Name Pester -Force -SkipPublisherCheck

# Run tests
Invoke-Pester -Path ./tests/infrastructure.tests.ps1
```

### Step 4: Deploy to Production (First Time)

**Important**: Deploy to production first to create the common management resources.

```bash
# Make a change to trigger deployment
git checkout main
echo "# Initial commit" >> demos/github-webapp-demo/README.md
git add .
git commit -m "Initial deployment - create common management resources"
git push origin main
```

This will:
1. Run unit tests
2. Wait for manual approval
3. Deploy Log Analytics Workspace
4. Deploy Management VNet
5. Deploy VM with GitHub runner (optional)
6. Deploy Application Gateway (optional)

### Step 5: Update Parameter Files After Production Deploy

After the production deployment completes, get the Log Analytics Workspace ID:

```bash
az monitor log-analytics workspace show \
  --resource-group rg-eastus-prod-mgmt-common \
  --workspace-name core-law \
  --query id -o tsv
```

Update the `logAnalyticsWorkspaceId` parameter in **dev.bicepparam** and **qa.bicepparam**.

Also update **prod.bicepparam**:
```bicep
param deployCommonMgmt = false  // Set to false after first deployment
```

Commit these changes:
```bash
git add demos/github-webapp-demo/parameters/
git commit -m "Update parameter files with Log Analytics Workspace ID"
git push origin main
```

### Step 6: Deploy to Dev Environment

```bash
git checkout dev
git merge main
git push origin dev
```

This will automatically deploy to the dev environment.

### Step 7: Deploy to QA Environment

```bash
git checkout qa
git merge main
git push origin qa
```

This will:
1. Run unit tests
2. Wait for manual approval (if configured)
3. Deploy to QA environment

---

## Testing

### Run Unit Tests

Unit tests run automatically on every pull request. To manually trigger:

```bash
# Using GitHub CLI
gh workflow run unit-tests.yml

# Or create a PR
git checkout -b feature/test-workflow
git push origin feature/test-workflow
gh pr create --title "Test workflow" --body "Testing CI/CD"
```

### Test the Application Locally

```bash
cd demos/github-webapp-demo/app

# Install dependencies
npm install

# Start the server
npm start

# Open browser to http://localhost:3000
```

### Test Deployed Application

After deployment, your web app will be accessible via:
- **Dev**: `https://app-webapp-dev-XXXX.azurewebsites.net`
- **QA**: `https://app-webapp-qa-XXXX.azurewebsites.net`
- **Prod**: `https://app-webapp-prod-XXXX.azurewebsites.net`

**Note**: If using private endpoints, the app is only accessible within the VNet.

Test endpoints:
```bash
# Health check
curl https://your-app.azurewebsites.net/health

# Application info
curl https://your-app.azurewebsites.net/api/info

# Key Vault test (requires authentication)
curl https://your-app.azurewebsites.net/api/secret
```

---

## Troubleshooting

### Issue: OIDC Authentication Fails - "Failed to login with Error: Error"

**Possible causes**:
1. Federated credentials not configured correctly
2. Incorrect GitHub secrets
3. Branch name mismatch
4. Repository name or organization mismatch

**Solution**:

```bash
# Verify federated credentials exist
APP_OBJECT_ID=$(az ad app list --display-name "github-actions-webapp-demo" --query "[0].id" -o tsv)
az ad app federated-credential list --id $APP_OBJECT_ID --output table

# Check the subject format matches your repository
# Should be: repo:GITHUB_ORG/REPO_NAME:ref:refs/heads/BRANCH_NAME

# Verify GitHub secrets are set
gh secret list

# Re-create federated credential if needed
az ad app federated-credential delete --id $APP_OBJECT_ID --federated-credential-id "github-main-branch"
# Then re-create with correct values
```

### Issue: "Error: Status: 403, Caller does not have permission to perform action"

**Possible causes**:
1. Service principal lacks required role assignments
2. Federated credential subject doesn't match the workflow context

**Solution**:

```bash
# Check role assignments
APP_ID=$(az ad app list --display-name "github-actions-webapp-demo" --query "[0].appId" -o tsv)
az role assignment list --assignee $APP_ID --output table

# Verify Contributor role is assigned at subscription level
az role assignment create \
  --assignee $APP_ID \
  --role "Contributor" \
  --scope "/subscriptions/YOUR_SUBSCRIPTION_ID"

# Check federated credential subject matches workflow branch
az ad app federated-credential list --id $APP_OBJECT_ID --query "[].{name:name,subject:subject}" -o table
```

### Issue: Missing or Incorrect GitHub Secrets

**Solution**:

```bash
# List current secrets
gh secret list

# Update specific secret
gh secret set AZURE_CLIENT_ID --body "NEW_VALUE"

# Delete and recreate all secrets
gh secret delete AZURE_CLIENT_ID
gh secret delete AZURE_TENANT_ID
gh secret delete AZURE_SUBSCRIPTION_ID

# Set correct values
gh secret set AZURE_CLIENT_ID --body "$(az ad app list --display-name 'github-actions-webapp-demo' --query '[0].appId' -o tsv)"
gh secret set AZURE_TENANT_ID --body "$(az account show --query tenantId -o tsv)"
gh secret set AZURE_SUBSCRIPTION_ID --body "YOUR_SUBSCRIPTION_ID"
```

### Issue: Deployment Fails with "Insufficient Permissions"

**Solution**: Ensure the service principal has Contributor role on the subscription:
```bash
az role assignment list --assignee YOUR_CLIENT_ID --output table
```

### Issue: Cannot Access Web App

**Possible causes**:
1. **Private endpoints enabled**: App is only accessible within VNet
2. **Deployment still in progress**: Wait for deployment to complete
3. **App Service not started**: Check App Service status in Azure Portal

**Solution**: Check deployment logs and App Service status.

### Issue: Key Vault Access Denied

**Solution**: Ensure the Web App's managed identity has the correct role:
```bash
# List role assignments for the web app
az role assignment list --assignee WEBAPP_PRINCIPAL_ID --output table

# Assign Key Vault Secrets User role if missing
az role assignment create \
  --assignee WEBAPP_PRINCIPAL_ID \
  --role "Key Vault Secrets User" \
  --scope KEY_VAULT_RESOURCE_ID
```

### Issue: GitHub Actions Workflow Fails

**Common causes**:
1. Missing or incorrect secrets
2. Invalid Bicep syntax
3. Azure resource conflicts
4. Permission issues

**Solution**: Check the workflow logs in GitHub Actions tab for detailed error messages.

### Issue: Bicep Validation Errors

**Solution**: Run local validation:
```bash
# Check for syntax errors
bicep build bicep/main.bicep

# Run linter
az bicep lint --file bicep/main.bicep
```

### Issue: Application Won't Start

**Solution**: Check App Service logs:
```bash
# Stream logs
az webapp log tail \
  --resource-group rg-eastus-dev-webapp \
  --name your-app-name

# Download logs
az webapp log download \
  --resource-group rg-eastus-dev-webapp \
  --name your-app-name \
  --log-file logs.zip
```

---

## Next Steps

After successful deployment:

1. Configure custom domain (optional)
2. Set up Application Insights alerts
3. Configure backup policies
4. Review and optimize costs
5. Set up additional environments if needed
6. Configure the GitHub self-hosted runner (if deployed)

---

## Cleaning Up

To remove all resources:

```bash
# Delete resource groups
az group delete --name rg-eastus-dev-webapp --yes --no-wait
az group delete --name rg-eastus-dev-webapp-networking --yes --no-wait
az group delete --name rg-eastus-qa-webapp --yes --no-wait
az group delete --name rg-eastus-qa-webapp-networking --yes --no-wait
az group delete --name rg-eastus-prod-webapp --yes --no-wait
az group delete --name rg-eastus-prod-webapp-networking --yes --no-wait
az group delete --name rg-eastus-prod-mgmt-common --yes --no-wait
az group delete --name rg-eastus-prod-mgmt-networking --yes --no-wait

# Delete application registration and service principal
APP_ID=$(az ad app list --display-name "github-actions-webapp-demo" --query "[0].appId" -o tsv)
az ad app delete --id $APP_ID

# Delete GitHub secrets
gh secret delete AZURE_CLIENT_ID
gh secret delete AZURE_TENANT_ID
gh secret delete AZURE_SUBSCRIPTION_ID
```

---

## Support

For issues or questions:
- Review the [README.md](README.md)
- Create an issue in the GitHub repository
- Contact the maintainers

---

**Happy Deploying!**
