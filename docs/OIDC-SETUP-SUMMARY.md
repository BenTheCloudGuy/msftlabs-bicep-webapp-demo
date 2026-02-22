# OIDC Configuration Summary

## Setup Completed: February 22, 2026

This document summarizes the OIDC authentication configuration between GitHub Actions and Azure for the **msftlabs-bicep-webapp-demo** repository.

---

## Azure Configuration

### App Registration
- **Name**: `github-actions-webapp-demo`
- **Application (Client) ID**: `7bbd7658-af23-4891-b3b5-c52a2879ebde`
- **Object ID**: `f3fdbd70-835a-4964-a1cf-0f99bdfa7bf4`
- **Tenant ID**: `477bacc4-4ada-4431-940b-b91cf6cb3fd4`

### Service Principal
- **Object ID**: `8adef45d-e890-4358-a11b-d96d53a90bfc`

### Target Subscription
- **Subscription ID**: `934600ac-0f19-44b8-b439-b4c5f02d8a7d`
- **Subscription Name**: msftlabs-misc-demos

---

## RBAC Role Assignments

The service principal has been assigned the following roles at the subscription level:

| Role | Scope | Purpose |
|------|-------|---------|
| **Contributor** | `/subscriptions/934600ac-0f19-44b8-b439-b4c5f02d8a7d` | Deploy and manage Azure resources |
| **User Access Administrator** | `/subscriptions/934600ac-0f19-44b8-b439-b4c5f02d8a7d` | Assign RBAC roles to deployed resources |

### Verification Command
```bash
az role assignment list \
  --assignee 7bbd7658-af23-4891-b3b5-c52a2879ebde \
  --scope "/subscriptions/934600ac-0f19-44b8-b439-b4c5f02d8a7d" \
  --query "[].{Role:roleDefinitionName, Scope:scope}" \
  -o table
```

---

## Federated Identity Credentials

Four federated identity credentials have been configured for branch-based and pull request deployments:

| Credential Name | Subject (Branch/Trigger) | Purpose |
|----------------|---------------------------|---------|
| **github-main-branch** | `repo:BenTheCloudGuy/msftlabs-bicep-webapp-demo:ref:refs/heads/main` | Production deployments |
| **github-dev-branch** | `repo:BenTheCloudGuy/msftlabs-bicep-webapp-demo:ref:refs/heads/dev` | Development deployments |
| **github-qa-branch** | `repo:BenTheCloudGuy/msftlabs-bicep-webapp-demo:ref:refs/heads/qa` | QA/staging deployments |
| **github-pull-requests** | `repo:BenTheCloudGuy/msftlabs-bicep-webapp-demo:pull_request` | PR validation |

### Configuration Details
- **Issuer**: `https://token.actions.githubusercontent.com`
- **Audience**: `api://AzureADTokenExchange`

### Verification Command
```bash
az ad app federated-credential list \
  --id f3fdbd70-835a-4964-a1cf-0f99bdfa7bf4 \
  --query "[].{Name:name, Subject:subject}" \
  -o table
```

---

## GitHub Repository Secrets

Three secrets have been configured in the GitHub repository:

| Secret Name | Value | Purpose |
|------------|--------|---------|
| **AZURE_CLIENT_ID** | `7bbd7658-af23-4891-b3b5-c52a2879ebde` | Azure App Registration client ID |
| **AZURE_TENANT_ID** | `477bacc4-4ada-4431-940b-b91cf6cb3fd4` | Azure Active Directory tenant ID |
| **AZURE_SUBSCRIPTION_ID** | `934600ac-0f19-44b8-b439-b4c5f02d8a7d` | Target Azure subscription |

### Verification Command
```bash
gh secret list --repo BenTheCloudGuy/msftlabs-bicep-webapp-demo
```

---

## Workflow Configuration

All GitHub Actions workflows are configured to use OIDC authentication with the following pattern:

```yaml
permissions:
  id-token: write      # Required for OIDC token generation
  contents: read       # Required for repository checkout

jobs:
  deploy:
    steps:
      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

### Key Requirements
- ✅ `id-token: write` permission at workflow or job level
- ✅ `azure/login@v1` action (not `actions/login`)
- ✅ Three secrets configured (CLIENT_ID, TENANT_ID, SUBSCRIPTION_ID)
- ✅ **No client secrets required** (passwordless authentication)

---

## Security Benefits

### 1. **No Stored Credentials**
- No client secrets or passwords stored in GitHub
- Tokens are short-lived (1 hour expiration)
- Tokens are generated on-demand per workflow run

### 2. **Least Privilege**
- Each branch has its own federated credential
- RBAC roles scoped to subscription level
- No global admin permissions required

### 3. **Audit Trail**
- All authentication attempts logged in Azure AD
- Deployment activities tracked in Azure Activity Log
- GitHub Actions provides detailed workflow logs

### 4. **Defense in Depth**
- Subject claims restrict token usage to specific branches
- Audience validation ensures tokens only work with Azure
- Repository-scoped credentials prevent cross-repository attacks

---

## Verification Steps

### 1. Verify Azure Configuration
```bash
# Check app registration
az ad app show --id f3fdbd70-835a-4964-a1cf-0f99bdfa7bf4

# Check service principal
az ad sp show --id 7bbd7658-af23-4891-b3b5-c52a2879ebde

# Check role assignments
az role assignment list \
  --assignee 7bbd7658-af23-4891-b3b5-c52a2879ebde \
  --scope "/subscriptions/934600ac-0f19-44b8-b439-b4c5f02d8a7d"

# Check federated credentials
az ad app federated-credential list \
  --id f3fdbd70-835a-4964-a1cf-0f99bdfa7bf4
```

### 2. Verify GitHub Configuration
```bash
# Check repository secrets
gh secret list --repo BenTheCloudGuy/msftlabs-bicep-webapp-demo

# View secret details (values are masked)
gh secret list --repo BenTheCloudGuy/msftlabs-bicep-webapp-demo --json name,updatedAt
```

### 3. Test Deployment
```bash
# Push to dev branch to trigger workflow
git checkout dev
git push origin dev

# Monitor workflow execution
gh run watch --repo BenTheCloudGuy/msftlabs-bicep-webapp-demo

# View workflow logs
gh run view --repo BenTheCloudGuy/msftlabs-bicep-webapp-demo --log
```

---

## Troubleshooting

### Issue: "AADSTS700016: Application not found"
**Solution**: Verify the CLIENT_ID secret matches the App Registration:
```bash
gh secret list --repo BenTheCloudGuy/msftlabs-bicep-webapp-demo
az ad app show --id 7bbd7658-af23-4891-b3b5-c52a2879ebde --query appId
```

### Issue: "No matching federated identity credential"
**Solution**: Verify subject claim matches branch name:
```bash
az ad app federated-credential list --id f3fdbd70-835a-4964-a1cf-0f99bdfa7bf4
```

### Issue: "InsufficientPermissionsInAccessToken"
**Solution**: Verify RBAC role assignments:
```bash
az role assignment list \
  --assignee 7bbd7658-af23-4891-b3b5-c52a2879ebde \
  --scope "/subscriptions/934600ac-0f19-44b8-b439-b4c5f02d8a7d"
```

### Issue: Workflow warnings about secrets
**Note**: Editor warnings like "Context access might be invalid: AZURE_CLIENT_ID" are expected. These are linter warnings because the editor can't validate GitHub secrets. The workflow will execute successfully.

---

## Next Steps

1. **Create Environment Branches** (if not already created):
   ```bash
   git checkout -b dev
   git push -u origin dev
   
   git checkout -b qa
   git push -u origin qa
   ```

2. **Test Workflows**:
   - Push changes to the `dev` branch
   - Verify OIDC authentication succeeds
   - Check deployment completes successfully

3. **Configure GitHub Environments** (Optional):
   - Create environments: `development`, `qa`, `production`
   - Add protection rules (required reviewers, wait timer)
   - Environment-specific secrets if needed

4. **Monitor Deployments**:
   - View workflow runs: `gh run list`
   - View workflow logs: `gh run view --log`
   - Check Azure deployments: `az deployment sub list`

---

## Documentation References

- **Quick Start**: [QUICKSTART.md](QUICKSTART.md) (10-minute setup)
- **Detailed Setup**: [SETUP.md](SETUP.md) (step-by-step guide)
- **OIDC Architecture**: [.github/OIDC-AUTHENTICATION.md](.github/OIDC-AUTHENTICATION.md)
- **Secrets Reference**: [.github/SECRETS-REFERENCE.md](.github/SECRETS-REFERENCE.md)
- **Setup Checklist**: [SETUP-CHECKLIST.md](SETUP-CHECKLIST.md)

---

## Cleanup (If Needed)

To remove the OIDC configuration:

```bash
# Delete GitHub secrets
gh secret delete AZURE_CLIENT_ID --repo BenTheCloudGuy/msftlabs-bicep-webapp-demo
gh secret delete AZURE_TENANT_ID --repo BenTheCloudGuy/msftlabs-bicep-webapp-demo
gh secret delete AZURE_SUBSCRIPTION_ID --repo BenTheCloudGuy/msftlabs-bicep-webapp-demo

# Delete role assignments
az role assignment delete \
  --assignee 7bbd7658-af23-4891-b3b5-c52a2879ebde \
  --scope "/subscriptions/934600ac-0f19-44b8-b439-b4c5f02d8a7d"

# Delete federated credentials
az ad app federated-credential delete \
  --id f3fdbd70-835a-4964-a1cf-0f99bdfa7bf4 \
  --federated-credential-id github-main-branch
az ad app federated-credential delete \
  --id f3fdbd70-835a-4964-a1cf-0f99bdfa7bf4 \
  --federated-credential-id github-dev-branch
az ad app federated-credential delete \
  --id f3fdbd70-835a-4964-a1cf-0f99bdfa7bf4 \
  --federated-credential-id github-qa-branch
az ad app federated-credential delete \
  --id f3fdbd70-835a-4964-a1cf-0f99bdfa7bf4 \
  --federated-credential-id github-pull-requests

# Delete service principal
az ad sp delete --id 7bbd7658-af23-4891-b3b5-c52a2879ebde

# Delete app registration
az ad app delete --id f3fdbd70-835a-4964-a1cf-0f99bdfa7bf4
```

---

**Configuration Date**: February 22, 2026  
**Configured By**: Automated via setup-oidc.ps1 script  
**Status**: ✅ Complete and verified
