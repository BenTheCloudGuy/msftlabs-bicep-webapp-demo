# OIDC Authentication for GitHub Actions

This document explains how OpenID Connect (OIDC) authentication works between GitHub Actions and Azure in this repository.

## Overview

This repository uses **federated identity credentials** (OIDC) instead of client secrets for Azure authentication. This approach:

- **No secrets stored**: No passwords or keys in GitHub secrets
- **Short-lived tokens**: Azure access tokens expire after workflow completion
- **Better security**: Eliminates secret rotation and credential leakage risks
- **Audit trail**: Azure AD logs all authentication attempts
- **Zero trust**: Tokens are bound to specific repositories and branches

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     GitHub Actions Workflow                      │
│                                                                   │
│  1. Workflow triggered (push/PR/manual)                          │
│  2. GitHub generates OIDC token with workflow context            │
│     - Repository: BenTheCloudGuy/msftlabs-bicep-webapp-demo     │
│     - Branch: main/dev/qa                                        │
│     - Actor: user                                                │
│     - Job workflow reference                                     │
└──────────────────────────────────┬────────────────────────────────┘
                                   │
                                   │ OIDC Token
                                   ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Azure AD (Entra ID)                      │
│                                                                   │
│  3. Receives OIDC token from GitHub                              │
│  4. Validates token signature (from GitHub)                      │
│  5. Checks federated credential configuration:                   │
│     - Issuer matches: token.actions.githubusercontent.com        │
│     - Subject matches: repo:ORG/REPO:ref:refs/heads/BRANCH      │
│     - Audience matches: api://AzureADTokenExchange               │
│  6. Issues Azure access token with assigned roles                │
└──────────────────────────────────┬────────────────────────────────┘
                                   │
                                   │ Azure Access Token
                                   ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Azure Resource Manager                      │
│                                                                   │
│  7. Workflow uses access token to deploy resources               │
│  8. Token inherits app registration role assignments             │
│     - Contributor on subscription                                │
│     - User Access Administrator (optional)                       │
│  9. Token expires when workflow completes                        │
└─────────────────────────────────────────────────────────────────┘
```

## Required Configuration

### 1. GitHub Repository Secrets

| Secret | Description | Example |
|--------|-------------|---------|
| `AZURE_CLIENT_ID` | Application (client) ID | `12345678-1234-1234-1234-123456789abc` |
| `AZURE_TENANT_ID` | Azure AD tenant ID | `87654321-4321-4321-4321-abcdefabcdef` |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | `abcdefab-cdef-abcd-efab-abcdefabcdef` |

**Note**: No `AZURE_CREDENTIALS` or client secret is needed with OIDC.

### 2. Azure App Registration

Created in: **Azure Portal** → **App Registrations**

- Name: `github-actions-webapp-demo`
- Service Principal: Auto-created
- Role Assignments:
  - `Contributor` on subscription (required)
  - `User Access Administrator` on subscription (optional, for RBAC assignments)

### 3. Federated Identity Credentials

Configured in: **App Registration** → **Certificates & secrets** → **Federated credentials**

| Name | Issuer | Subject | Audience |
|------|--------|---------|----------|
| `github-main-branch` | `https://token.actions.githubusercontent.com` | `repo:BenTheCloudGuy/msftlabs-bicep-webapp-demo:ref:refs/heads/main` | `api://AzureADTokenExchange` |
| `github-dev-branch` | `https://token.actions.githubusercontent.com` | `repo:BenTheCloudGuy/msftlabs-bicep-webapp-demo:ref:refs/heads/dev` | `api://AzureADTokenExchange` |
| `github-qa-branch` | `https://token.actions.githubusercontent.com` | `repo:BenTheCloudGuy/msftlabs-bicep-webapp-demo:ref:refs/heads/qa` | `api://AzureADTokenExchange` |
| `github-pull-requests` | `https://token.actions.githubusercontent.com` | `repo:BenTheCloudGuy/msftlabs-bicep-webapp-demo:pull_request` | `api://AzureADTokenExchange` |

**Important**: The `subject` field must exactly match the repository and branch/PR context.

## Workflow Configuration

### Required Permissions

All workflows must include these permissions:

```yaml
permissions:
  id-token: write    # Required for OIDC authentication
  contents: read     # Required to checkout repository code
```

**Why `id-token: write`?** This allows GitHub Actions to request an OIDC token from GitHub's token service.

### Azure Login Step

```yaml
- name: Azure Login
  uses: azure/login@v1
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

**What happens:**
1. The `azure/login` action requests an OIDC token from GitHub
2. GitHub generates a token with workflow context (repo, branch, actor)
3. The action sends the token to Azure AD
4. Azure AD validates the token against federated credentials
5. Azure AD returns an Azure access token
6. The token is set in the Azure CLI session for subsequent steps

## Subject Format

The `subject` field in federated credentials uses this format:

### Branch Deployments
```
repo:ORGANIZATION/REPOSITORY:ref:refs/heads/BRANCH_NAME
```

Example:
```
repo:BenTheCloudGuy/msftlabs-bicep-webapp-demo:ref:refs/heads/main
```

### Pull Request Validations
```
repo:ORGANIZATION/REPOSITORY:pull_request
```

Example:
```
repo:BenTheCloudGuy/msftlabs-bicep-webapp-demo:pull_request
```

### Environment-Specific (Optional)
```
repo:ORGANIZATION/REPOSITORY:environment:ENVIRONMENT_NAME
```

Example:
```
repo:BenTheCloudGuy/msftlabs-bicep-webapp-demo:environment:production
```

## Token Claims

GitHub's OIDC token includes these claims (verified by Azure AD):

```json
{
  "iss": "https://token.actions.githubusercontent.com",
  "sub": "repo:BenTheCloudGuy/msftlabs-bicep-webapp-demo:ref:refs/heads/main",
  "aud": "api://AzureADTokenExchange",
  "repository": "BenTheCloudGuy/msftlabs-bicep-webapp-demo",
  "repository_owner": "BenTheCloudGuy",
  "ref": "refs/heads/main",
  "sha": "abc123def456...",
  "workflow": "Deploy to Production",
  "actor": "username",
  "job_workflow_ref": "BenTheCloudGuy/msftlabs-bicep-webapp-demo/.github/workflows/deploy-prod.yml@refs/heads/main"
}
```

## Security Benefits

### 1. No Credential Storage
- No client secrets in GitHub secrets
- No passwords or keys to rotate
- No risk of accidental exposure in logs

### 2. Least Privilege
- Tokens are scoped to specific repositories
- Tokens are bound to specific branches or PRs
- Tokens automatically expire after workflow completion

### 3. Audit Trail
- Azure AD logs all authentication attempts
- Tokens include workflow context for traceability
- Failed authentication attempts are logged

### 4. Defense in Depth
- Compromised GitHub account cannot access Azure without valid workflow context
- Stolen tokens are short-lived (typically < 1 hour)
- Repository must match federated credential configuration

## Troubleshooting

### Error: "Failed to login with Error: Error"

**Cause**: Federated credential subject doesn't match workflow context.

**Solution**:
```bash
# Check federated credentials
APP_OBJECT_ID=$(az ad app list --display-name "github-actions-webapp-demo" --query "[0].id" -o tsv)
az ad app federated-credential list --id $APP_OBJECT_ID --query "[].{name:name,subject:subject}" -o table

# Verify subject format matches: repo:ORG/REPO:ref:refs/heads/BRANCH
```

### Error: "Status: 403, Caller does not have permission"

**Cause**: Service principal lacks required role assignments.

**Solution**:
```bash
# Check role assignments
APP_ID=$(az ad app list --display-name "github-actions-webapp-demo" --query "[0].appId" -o tsv)
az role assignment list --assignee $APP_ID --output table

# Assign Contributor role
az role assignment create \
  --assignee $APP_ID \
  --role "Contributor" \
  --scope "/subscriptions/YOUR_SUBSCRIPTION_ID"
```

### Error: "Audience validation failed"

**Cause**: Federated credential has incorrect audience value.

**Solution**: Audience must be `api://AzureADTokenExchange`
```bash
# Delete and recreate credential with correct audience
az ad app federated-credential delete --id $APP_OBJECT_ID --federated-credential-id "CREDENTIAL_NAME"
# Recreate with correct audience
```

### Error: "The issuer is invalid"

**Cause**: Federated credential has incorrect issuer.

**Solution**: Issuer must be `https://token.actions.githubusercontent.com`

## Verification Commands

```bash
# Get app registration details
APP_NAME="github-actions-webapp-demo"
APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
APP_OBJECT_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].id" -o tsv)

# List role assignments
echo "Role Assignments:"
az role assignment list --assignee $APP_ID --output table

# List federated credentials
echo ""
echo "Federated Credentials:"
az ad app federated-credential list --id $APP_OBJECT_ID --output table

# Check GitHub secrets (requires GitHub CLI)
echo ""
echo "GitHub Secrets:"
gh secret list
```

## Additional Resources

- [Azure OIDC with GitHub Actions - Microsoft Learn](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure)
- [Security hardening with OpenID Connect - GitHub Docs](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [Configuring OpenID Connect in Azure - GitHub Docs](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [Workload identity federation - Microsoft Learn](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation)
- [Azure Login Action - GitHub Marketplace](https://github.com/marketplace/actions/azure-login)

## Support

For issues with OIDC authentication:
1. Check workflow logs in GitHub Actions
2. Verify federated credentials match repository/branch names exactly
3. Confirm all three GitHub secrets are set correctly
4. Review Azure AD sign-in logs for authentication failures

For setup assistance, see [SETUP.md](../SETUP.md) or [QUICKSTART.md](../QUICKSTART.md).
