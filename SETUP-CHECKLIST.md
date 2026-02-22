# Setup Checklist

Use this checklist to verify your GitHub Actions and Azure OIDC configuration is complete.

## Azure Configuration

### App Registration

- [ ] Created Azure App Registration named `github-actions-webapp-demo`
- [ ] Recorded Application (client) ID
- [ ] Recorded Tenant ID  
- [ ] Service Principal created automatically

**Verify**:
```bash
az ad app list --display-name "github-actions-webapp-demo" --query "[].{Name:displayName,AppId:appId}" -o table
```

### Role Assignments

- [ ] Assigned **Contributor** role at subscription level
- [ ] (Optional) Assigned **User Access Administrator** role for RBAC assignments
- [ ] (Optional) Assigned **Resource Policy Contributor** role for policy assignments

**Verify**:
```bash
APP_ID=$(az ad app list --display-name "github-actions-webapp-demo" --query "[0].appId" -o tsv)
az role assignment list --assignee $APP_ID --output table
```

Expected output should show at least:
- `Contributor` on `/subscriptions/YOUR_SUBSCRIPTION_ID`

### Federated Identity Credentials

- [ ] Created credential for **main** branch (production)
  - Name: `github-main-branch`
  - Subject: `repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main`
  - Issuer: `https://token.actions.githubusercontent.com`
  - Audience: `api://AzureADTokenExchange`

- [ ] Created credential for **dev** branch
  - Name: `github-dev-branch`
  - Subject: `repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/dev`
  - Issuer: `https://token.actions.githubusercontent.com`
  - Audience: `api://AzureADTokenExchange`

- [ ] Created credential for **qa** branch
  - Name: `github-qa-branch`
  - Subject: `repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/qa`
  - Issuer: `https://token.actions.githubusercontent.com`
  - Audience: `api://AzureADTokenExchange`

- [ ] Created credential for **pull requests**
  - Name: `github-pull-requests`
  - Subject: `repo:YOUR_ORG/YOUR_REPO:pull_request`
  - Issuer: `https://token.actions.githubusercontent.com`
  - Audience: `api://AzureADTokenExchange`

**Verify**:
```bash
APP_OBJECT_ID=$(az ad app list --display-name "github-actions-webapp-demo" --query "[0].id" -o tsv)
az ad app federated-credential list --id $APP_OBJECT_ID --output table
```

Expected output should show 4 federated credentials.

---

## GitHub Configuration

### Repository Secrets

- [ ] Set **AZURE_CLIENT_ID** secret
  - Value: Application (client) ID from Azure App Registration
  
- [ ] Set **AZURE_TENANT_ID** secret
  - Value: Azure AD tenant ID
  
- [ ] Set **AZURE_SUBSCRIPTION_ID** secret
  - Value: Target Azure subscription ID

**Verify** (using GitHub CLI):
```bash
gh secret list
```

Expected output:
```
AZURE_CLIENT_ID        Updated YYYY-MM-DD
AZURE_SUBSCRIPTION_ID  Updated YYYY-MM-DD
AZURE_TENANT_ID        Updated YYYY-MM-DD
```

**Verify** (using GitHub Web UI):
1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Confirm all three secrets are listed

### Repository Branches

- [ ] Created **dev** branch
- [ ] Created **qa** branch
- [ ] **main** branch exists (default)

**Verify**:
```bash
git branch -a
```

Expected output should include:
```
  main
  dev
  qa
  remotes/origin/main
  remotes/origin/dev
  remotes/origin/qa
```

### GitHub Environments (Optional)

- [ ] Created **development** environment
  - No protection rules (optional)
  
- [ ] Created **qa** environment
  - Required reviewers configured (recommended)
  - Wait timer: 5 minutes (optional)
  
- [ ] Created **production** environment
  - Required reviewers configured (recommended)
  - Wait timer: 30 minutes (optional)
  - Branch protection: Only `main` branch (recommended)

**Verify**:
1. Go to **Settings** → **Environments**
2. Confirm environments are listed

---

## Workflow Files

### Workflow Permissions

Verify all workflow files include these permissions:

- [ ] `unit-tests.yml` has `id-token: write` and `contents: read`
- [ ] `deploy-dev.yml` has `id-token: write` and `contents: read`
- [ ] `deploy-qa.yml` has `id-token: write` and `contents: read`
- [ ] `deploy-prod.yml` has `id-token: write` and `contents: read`
- [ ] `cost-estimation.yml` has `id-token: write` and `contents: read`

**Verify**:
```bash
# Check all workflows have correct permissions
grep -A 3 "permissions:" .github/workflows/*.yml
```

### Azure Login Steps

Verify all workflows use correct Azure login configuration:

- [ ] All workflows use `azure/login@v1` action
- [ ] All workflows reference `${{ secrets.AZURE_CLIENT_ID }}`
- [ ] All workflows reference `${{ secrets.AZURE_TENANT_ID }}`
- [ ] All workflows reference `${{ secrets.AZURE_SUBSCRIPTION_ID }}`

**Verify**:
```bash
# Check Azure login configuration
grep -A 5 "azure/login" .github/workflows/*.yml
```

---

## Testing

### Local Validation

- [ ] Bicep CLI installed: `az bicep version`
- [ ] Bicep files compile without errors: `bicep build bicep/main.bicep`
- [ ] No linting warnings: `az bicep lint --file bicep/main.bicep`

**Verify**:
```bash
cd demos/github-webapp-demo
bicep build bicep/main.bicep
echo "Exit code: $?"  # Should be 0
```

### Test OIDC Authentication

- [ ] Created test branch
- [ ] Pushed commit to trigger workflow
- [ ] Workflow run shows successful Azure login
- [ ] No authentication errors in workflow logs

**Test**:
```bash
# Create test branch
git checkout -b test-oidc-auth
git commit --allow-empty -m "Test OIDC authentication"
git push -u origin test-oidc-auth

# Check workflow status
gh run list --branch test-oidc-auth
gh run view --log  # View latest run logs
```

Expected: Azure login step should succeed with message like:
```
Login successful.
```

### Test Deployment (Optional)

- [ ] Dev deployment succeeds
- [ ] QA deployment succeeds (with approval)
- [ ] Production deployment succeeds (with approval)

**Test**:
```bash
# Trigger dev deployment
git checkout dev
echo "test" >> README.md
git commit -am "Test dev deployment"
git push origin dev

# Check deployment status
gh run list --branch dev
```

---

## Common Issues

### Authentication Fails

If Azure login fails with "Failed to login with Error: Error":

**Check**:
1. [ ] GitHub secrets are set correctly (no typos)
2. [ ] Federated credential subject matches repository exactly
3. [ ] Repository name and organization are correct in subject
4. [ ] Branch name in subject matches actual branch name

**Fix**:
```bash
# Verify credential subjects
APP_OBJECT_ID=$(az ad app list --display-name "github-actions-webapp-demo" --query "[0].id" -o tsv)
az ad app federated-credential list --id $APP_OBJECT_ID --query "[].{name:name,subject:subject}" -o table

# Subject should match EXACTLY: repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/BRANCH_NAME
```

### Permission Denied

If deployment fails with "403 Forbidden" or "insufficient permissions":

**Check**:
1. [ ] Contributor role is assigned at subscription level
2. [ ] Role assignment is on correct subscription
3. [ ] Service principal is not disabled

**Fix**:
```bash
# Re-assign Contributor role
APP_ID=$(az ad app list --display-name "github-actions-webapp-demo" --query "[0].appId" -o tsv)
az role assignment create \
  --assignee $APP_ID \
  --role "Contributor" \
  --scope "/subscriptions/YOUR_SUBSCRIPTION_ID"
```

### Workflow Doesn't Trigger

If pushing to branch doesn't trigger workflow:

**Check**:
1. [ ] Branch name matches workflow trigger configuration
2. [ ] Workflow files are in `.github/workflows/` directory
3. [ ] Workflow syntax is valid YAML
4. [ ] Repository has Actions enabled (Settings → Actions)

---

## Verification Script

Run this script to verify all configuration:

```bash
#!/bin/bash

echo "==================================="
echo "Configuration Verification"
echo "==================================="

# Variables (UPDATE THESE)
APP_NAME="github-actions-webapp-demo"
SUBSCRIPTION_ID="YOUR_SUBSCRIPTION_ID"

# Get IDs
APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
APP_OBJECT_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].id" -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo ""
echo "1. Azure App Registration:"
if [ -z "$APP_ID" ]; then
  echo "   ❌ App registration not found"
else
  echo "   ✅ App ID: $APP_ID"
fi

echo ""
echo "2. Role Assignments:"
ROLES=$(az role assignment list --assignee $APP_ID --query "[].roleDefinitionName" -o tsv)
if echo "$ROLES" | grep -q "Contributor"; then
  echo "   ✅ Contributor role assigned"
else
  echo "   ❌ Contributor role NOT assigned"
fi

echo ""
echo "3. Federated Credentials:"
CRED_COUNT=$(az ad app federated-credential list --id $APP_OBJECT_ID --query "length([])" -o tsv)
if [ "$CRED_COUNT" -ge 4 ]; then
  echo "   ✅ $CRED_COUNT federated credentials configured"
else
  echo "   ⚠️  Only $CRED_COUNT federated credentials found (expected 4)"
fi

echo ""
echo "4. GitHub Secrets:"
SECRET_COUNT=$(gh secret list | wc -l)
if [ "$SECRET_COUNT" -ge 3 ]; then
  echo "   ✅ $SECRET_COUNT secrets configured"
  gh secret list
else
  echo "   ❌ Only $SECRET_COUNT secrets found (expected 3)"
fi

echo ""
echo "5. GitHub Branches:"
git branch -a | grep -E "(main|dev|qa)" | wc -l
if [ $(git branch -a | grep -E "(main|dev|qa)" | wc -l) -ge 3 ]; then
  echo "   ✅ Required branches exist"
else
  echo "   ⚠️  Some branches may be missing"
fi

echo ""
echo "==================================="
echo "Configuration Values:"
echo "==================================="
echo "AZURE_CLIENT_ID: $APP_ID"
echo "AZURE_TENANT_ID: $TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
echo "==================================="
```

---

## Summary

When all items are checked:
- ✅ Azure App Registration created with correct permissions
- ✅ Federated credentials configured for all branches
- ✅ GitHub secrets configured correctly
- ✅ Branches created and pushed to GitHub
- ✅ Workflows configured with correct permissions
- ✅ Test authentication successful

**You're ready to deploy!** 🚀

For detailed instructions, see:
- [Quick Start Guide](QUICKSTART.md)
- [Setup Guide](SETUP.md)
- [OIDC Authentication Guide](.github/OIDC-AUTHENTICATION.md)
