# Quick Start: OIDC Setup for GitHub Actions

This guide provides a streamlined setup for experienced users. For detailed explanations, see [SETUP.md](SETUP.md).

## Prerequisites

- Azure CLI installed and logged in
- GitHub CLI installed (optional but recommended)
- Owner or Contributor access to Azure subscription
- Admin access to GitHub repository

## 1. Azure Configuration (5 minutes)

```bash
# Set variables (UPDATE THESE)
SUBSCRIPTION_ID="YOUR_SUBSCRIPTION_ID"
GITHUB_ORG="YOUR_GITHUB_ORG"              # Example: "BenTheCloudGuy"
REPO_NAME="YOUR_REPO_NAME"                # Example: "msftlabs-bicep-webapp-demo"
APP_NAME="github-actions-webapp-demo"

# Login and set subscription
az login
az account set --subscription "$SUBSCRIPTION_ID"

# Create app registration
az ad app create --display-name "$APP_NAME"
APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
APP_OBJECT_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].id" -o tsv)

# Create service principal
az ad sp create --id $APP_ID

# Assign Contributor role
az role assignment create \
  --assignee $APP_ID \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# (Optional) Assign User Access Administrator role for RBAC assignments
az role assignment create \
  --assignee $APP_ID \
  --role "User Access Administrator" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# Create federated credentials for each branch
az ad app federated-credential create \
  --id $APP_OBJECT_ID \
  --parameters "{
    \"name\": \"github-main-branch\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:$GITHUB_ORG/$REPO_NAME:ref:refs/heads/main\",
    \"description\": \"GitHub Actions - Main Branch (Production)\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

az ad app federated-credential create \
  --id $APP_OBJECT_ID \
  --parameters "{
    \"name\": \"github-dev-branch\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:$GITHUB_ORG/$REPO_NAME:ref:refs/heads/dev\",
    \"description\": \"GitHub Actions - Dev Branch\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

az ad app federated-credential create \
  --id $APP_OBJECT_ID \
  --parameters "{
    \"name\": \"github-qa-branch\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:$GITHUB_ORG/$REPO_NAME:ref:refs/heads/qa\",
    \"description\": \"GitHub Actions - QA Branch\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

az ad app federated-credential create \
  --id $APP_OBJECT_ID \
  --parameters "{
    \"name\": \"github-pull-requests\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:$GITHUB_ORG/$REPO_NAME:pull_request\",
    \"description\": \"GitHub Actions - Pull Requests\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

# Get tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)

# Display configuration summary
echo ""
echo "================================================"
echo "Azure OIDC Configuration Complete!"
echo "================================================"
echo "Application Name: $APP_NAME"
echo "Application ID: $APP_ID"
echo "Tenant ID: $TENANT_ID"
echo "Subscription ID: $SUBSCRIPTION_ID"
echo "================================================"
echo ""
echo "Copy these values for GitHub secrets configuration:"
echo ""
```

## 2. GitHub Configuration (2 minutes)

### Option A: Using GitHub CLI (Recommended)

```bash
# Set GitHub secrets
gh secret set AZURE_CLIENT_ID --body "$APP_ID"
gh secret set AZURE_TENANT_ID --body "$TENANT_ID"
gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID"

# Verify secrets
gh secret list
```

### Option B: Using GitHub Web UI

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret** and add:
   - `AZURE_CLIENT_ID` = Your Application ID
   - `AZURE_TENANT_ID` = Your Tenant ID
   - `AZURE_SUBSCRIPTION_ID` = Your Subscription ID

## 3. Verification (1 minute)

```bash
# Verify Azure configuration
echo "Role Assignments:"
az role assignment list --assignee $APP_ID --output table

echo ""
echo "Federated Credentials:"
az ad app federated-credential list --id $APP_OBJECT_ID --output table

# Verify GitHub secrets
echo ""
echo "GitHub Secrets:"
gh secret list
```

Expected output:
- Role assignments: Contributor (and optionally User Access Administrator)
- Federated credentials: 4 credentials (main, dev, qa, pull_request)
- GitHub secrets: 3 secrets (AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID)

## 4. Test the Configuration

```bash
# Create a test branch and trigger workflow
git checkout -b test-oidc
git commit --allow-empty -m "Test OIDC authentication"
git push -u origin test-oidc

# Open GitHub Actions to see the workflow run
gh workflow list
```

## Troubleshooting

### OIDC authentication fails

```bash
# Check federated credential subjects match repository
az ad app federated-credential list --id $APP_OBJECT_ID --query "[].{name:name,subject:subject}" -o table

# Subject should be: repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/BRANCH_NAME
```

### Permission denied errors

```bash
# Verify role assignments
az role assignment list --assignee $APP_ID --output table

# Re-assign Contributor role if missing
az role assignment create \
  --assignee $APP_ID \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"
```

### Secrets not found

```bash
# List current secrets
gh secret list

# Re-create missing secrets
gh secret set AZURE_CLIENT_ID --body "$APP_ID"
gh secret set AZURE_TENANT_ID --body "$TENANT_ID"
gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID"
```

## What's Next?

1. Create GitHub environments (dev, qa, production) in Settings → Environments
2. Configure branch protection rules
3. Update parameter files with your values
4. Trigger your first deployment

See [SETUP.md](SETUP.md) for detailed deployment instructions.

## Cleanup

```bash
# Delete app registration and all associated resources
az ad app delete --id $APP_ID

# Delete GitHub secrets
gh secret delete AZURE_CLIENT_ID
gh secret delete AZURE_TENANT_ID
gh secret delete AZURE_SUBSCRIPTION_ID
```

## Additional Resources

- [Azure OIDC with GitHub Actions](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure)
- [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Federated Identity Credentials](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation)
- [GitHub Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
