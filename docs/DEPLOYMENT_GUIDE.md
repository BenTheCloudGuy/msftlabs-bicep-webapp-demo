# Quick Deployment Reference

## Prerequisites ✅

Before deploying, ensure you have:

1. **Azure CLI** installed and authenticated
2. **Bicep CLI** installed (comes with Azure CLI)
3. **PowerShell** 7+ (for setup scripts)
4. **Permissions:**
   - Subscription Owner or Contributor role
   - Key Vault Administrator role on target KeyVault

---

## First Time Setup (Production Only) 🚀

### Step 1: Setup KeyVault with VM Password

```powershell
# Navigate to repository
cd c:\Users\bemitchell\.working\repos\mcaps\msftlabs-bicep-webapp-demo

# Run KeyVault setup script
.\scripts\setup-keyvault-secrets.ps1 `
    -SubscriptionId "934600ac-0f19-44b8-b439-b4c5f02d8a7d" `
    -ResourceGroupName "rg-centralus-prod-mgmt-common" `
    -KeyVaultName "kv-mgmt-prod-secrets" `
    -Location "centralus" `
    -VmAdminPassword (Read-Host -AsSecureString -Prompt "Enter VM Admin Password")
```

### Step 2: Deploy Production Infrastructure (First Time)

```bash
# Set subscription
az account set --subscription "934600ac-0f19-44b8-b439-b4c5f02d8a7d"

# Deploy with deployCommonMgmt = true (creates Log Analytics Workspace)
az deployment sub create \
  --name "deploy-prod-initial-$(date +%Y%m%d-%H%M%S)" \
  --location centralus \
  --template-file bicep/main.bicep \
  --parameters parameters/prod.bicepparam \
  --parameters deployedBy="$USER"
```

### Step 3: Update prod.bicepparam After First Deploy

After successful deployment, update `parameters/prod.bicepparam`:

```bicep
# Change this:
param deployCommonMgmt = true
param logAnalyticsWorkspaceId = ''

# To this:
param deployCommonMgmt = false
param logAnalyticsWorkspaceId = '/subscriptions/934600ac-0f19-44b8-b439-b4c5f02d8a7d/resourceGroups/rg-centralus-prod-mgmt-common/providers/Microsoft.OperationalInsights/workspaces/core-law'
```

---

## Environment Deployments 🌍

### Deploy Development Environment

```bash
az account set --subscription "934600ac-0f19-44b8-b439-b4c5f02d8a7d"

az deployment sub create \
  --name "deploy-dev-$(date +%Y%m%d-%H%M%S)" \
  --location centralus \
  --template-file bicep/main.bicep \
  --parameters parameters/dev.bicepparam \
  --parameters deployedBy="$USER"
```

### Deploy QA Environment

```bash
az account set --subscription "934600ac-0f19-44b8-b439-b4c5f02d8a7d"

az deployment sub create \
  --name "deploy-qa-$(date +%Y%m%d-%H%M%S)" \
  --location centralus \
  --template-file bicep/main.bicep \
  --parameters parameters/qa.bicepparam \
  --parameters deployedBy="$USER"
```

### Deploy Production Environment (Subsequent Deployments)

```bash
az account set --subscription "934600ac-0f19-44b8-b439-b4c5f02d8a7d"

az deployment sub create \
  --name "deploy-prod-$(date +%Y%m%d-%H%M%S)" \
  --location centralus \
  --template-file bicep/main.bicep \
  --parameters parameters/prod.bicepparam \
  --parameters deployedBy="$USER"
```

---

## Validation Commands 🔍

### Check Deployment Status

```bash
# List recent deployments
az deployment sub list \
  --subscription "934600ac-0f19-44b8-b439-b4c5f02d8a7d" \
  --query "[?contains(name, 'deploy-')].{Name:name, State:properties.provisioningState, Timestamp:properties.timestamp}" \
  --output table

# Get specific deployment details
az deployment sub show \
  --name "deploy-prod-20250122-143000" \
  --query "{State:properties.provisioningState, Duration:properties.duration, Outputs:properties.outputs}"
```

### Verify Resources Created

```bash
# List all resource groups
az group list \
  --subscription "934600ac-0f19-44b8-b439-b4c5f02d8a7d" \
  --query "[?contains(name, 'webapp')].{Name:name, Location:location}" \
  --output table

# List resources in dev environment
az resource list \
  --resource-group "rg-centralus-dev-webapp" \
  --query "[].{Name:name, Type:type, Location:location}" \
  --output table

# Check Web App status
az webapp show \
  --resource-group "rg-centralus-dev-webapp" \
  --name "app-webapp-dev-<unique-string>" \
  --query "{Name:name, State:state, DefaultHostName:defaultHostName}" \
  --output table
```

### Verify KeyVault Secret

```bash
# Check KeyVault secret exists
az keyvault secret list \
  --vault-name "kv-mgmt-prod-secrets" \
  --query "[?contains(name, 'vmAdmin')].{Name:name, Enabled:attributes.enabled}" \
  --output table

# Get secret metadata (not the value)
az keyvault secret show \
  --vault-name "kv-mgmt-prod-secrets" \
  --name "vmAdminPassword" \
  --query "{Name:name, Created:attributes.created, Updated:attributes.updated, Enabled:attributes.enabled}"
```

### Check Log Analytics Workspace

```bash
# Verify workspace exists and is active
az monitor log-analytics workspace show \
  --resource-group "rg-centralus-prod-mgmt-common" \
  --workspace-name "core-law" \
  --query "{Name:name, ProvisioningState:provisioningState, RetentionInDays:retentionInDays, Sku:sku.name}" \
  --output table

# Check workspace is receiving data
az monitor log-analytics workspace table list \
  --resource-group "rg-centralus-prod-mgmt-common" \
  --workspace-name "core-law" \
  --query "[0:5].{Name:name, RetentionInDays:retentionInDays}" \
  --output table
```

---

## Troubleshooting 🔧

### Issue: KeyVault Secret Not Found

**Error:** `Cannot retrieve secret 'vmAdminPassword' from KeyVault`

**Solution:**
```powershell
# Re-run setup script
.\scripts\setup-keyvault-secrets.ps1 `
    -SubscriptionId "934600ac-0f19-44b8-b439-b4c5f02d8a7d" `
    -ResourceGroupName "rg-centralus-prod-mgmt-common" `
    -KeyVaultName "kv-mgmt-prod-secrets" `
    -Location "centralus" `
    -VmAdminPassword (Read-Host -AsSecureString)
```

### Issue: RBAC Permission Denied on KeyVault

**Error:** `The user, group or application does not have secrets get permission`

**Solution:**
```bash
# Get current user principal ID
PRINCIPAL_ID=$(az ad signed-in-user show --query id -o tsv)

# Assign Key Vault Secrets User role
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee $PRINCIPAL_ID \
  --scope "/subscriptions/934600ac-0f19-44b8-b439-b4c5f02d8a7d/resourceGroups/rg-centralus-prod-mgmt-common/providers/Microsoft.KeyVault/vaults/kv-mgmt-prod-secrets"

# Wait for RBAC propagation
sleep 30
```

### Issue: Log Analytics Workspace Not Found

**Error:** `The Resource 'Microsoft.OperationalInsights/workspaces/core-law' was not found`

**Solution:**
1. Deploy production environment first with `deployCommonMgmt = true`
2. Wait for deployment to complete
3. Update dev/qa parameter files with correct Log Analytics Workspace resource ID
4. Redeploy environments

### Issue: Bicep Compilation Errors

**Solution:**
```bash
# Validate Bicep file
az bicep build --file bicep/main.bicep

# Lint Bicep file
bicep lint bicep/main.bicep

# Check parameter file
az bicep build-params --file parameters/dev.bicepparam
```

### Issue: Deployment What-If Doesn't Show Changes

**Solution:**
```bash
# Run what-if to preview changes
az deployment sub what-if \
  --name "deploy-dev-whatif" \
  --location centralus \
  --template-file bicep/main.bicep \
  --parameters parameters/dev.bicepparam \
  --parameters deployedBy="$USER"
```

---

## Cleanup Commands 🧹

### Delete Development Environment

```bash
# Delete dev resource groups
az group delete --name "rg-centralus-dev-webapp" --yes --no-wait
az group delete --name "rg-centralus-dev-webapp-networking" --yes --no-wait
```

### Delete QA Environment

```bash
# Delete QA resource groups
az group delete --name "rg-centralus-qa-webapp" --yes --no-wait
az group delete --name "rg-centralus-qa-webapp-networking" --yes --no-wait
```

### Delete Production Environment (⚠️ USE WITH CAUTION)

```bash
# Delete prod resource groups
az group delete --name "rg-centralus-prod-webapp" --yes --no-wait
az group delete --name "rg-centralus-prod-webapp-networking" --yes --no-wait

# Delete common management (only if fully decommissioning)
az group delete --name "rg-centralus-prod-mgmt-common" --yes --no-wait
az group delete --name "rg-centralus-prod-mgmt-networking" --yes --no-wait
```

---

## GitHub Actions Integration 🔄

### Required GitHub Secrets

Configure these secrets in your GitHub repository:

```yaml
AZURE_CLIENT_ID: "<service-principal-client-id>"
AZURE_TENANT_ID: "<azure-tenant-id>"
AZURE_SUBSCRIPTION_ID: "934600ac-0f19-44b8-b439-b4c5f02d8a7d"
```

### Service Principal Setup

```bash
# Create service principal with Contributor role
az ad sp create-for-rbac \
  --name "sp-github-webapp-deploy" \
  --role "Contributor" \
  --scopes "/subscriptions/934600ac-0f19-44b8-b439-b4c5f02d8a7d" \
  --sdk-auth

# Grant Key Vault Secrets User role to service principal
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee "<service-principal-client-id>" \
  --scope "/subscriptions/934600ac-0f19-44b8-b439-b4c5f02d8a7d/resourceGroups/rg-centralus-prod-mgmt-common/providers/Microsoft.KeyVault/vaults/kv-mgmt-prod-secrets"
```

### Manual Workflow Trigger

```bash
# Trigger workflow manually via GitHub CLI
gh workflow run deploy.yml \
  --field environment=dev \
  --field deployedBy="$USER"
```

---

## Parameter File Locations 📁

```
parameters/
├── dev.bicepparam    # Development environment
├── qa.bicepparam     # QA environment
└── prod.bicepparam   # Production environment
```

## Key Configuration Values ⚙️

| Parameter | Dev | QA | Prod |
|-----------|-----|-----|------|
| **Region** | centralus | centralus | centralus |
| **Subscription** | 934600ac-0f19-44b8-b439-b4c5f02d8a7d | 934600ac-0f19-44b8-b439-b4c5f02d8a7d | 934600ac-0f19-44b8-b439-b4c5f02d8a7d |
| **Common Mgmt** | false | false | true (first), false (subsequent) |
| **App Gateway** | false | false | true |
| **Self-Hosted Runner** | false | false | true |
| **KeyVault Name** | kv-mgmt-prod-secrets | kv-mgmt-prod-secrets | kv-mgmt-prod-secrets |
| **LAW Resource ID** | Existing (see params) | Existing (see params) | Created on first deploy |

---

## Support & Documentation 📚

- **Full Architecture Changes:** See [ARCHITECTURE_CHANGES.md](ARCHITECTURE_CHANGES.md)
- **Setup Documentation:** See [SETUP.md](SETUP.md)
- **Repository README:** See [README.md](README.md)

---

## Quick Command Cheatsheet 📋

```bash
# Validate before deploy
az bicep build --file bicep/main.bicep

# What-if deployment
az deployment sub what-if --location centralus --template-file bicep/main.bicep --parameters parameters/dev.bicepparam

# Deploy with custom parameter
az deployment sub create --location centralus --template-file bicep/main.bicep --parameters parameters/dev.bicepparam --parameters deployedBy="$USER"

# Check deployment status
az deployment sub show --name "<deployment-name>" --query "properties.provisioningState"

# View deployment outputs
az deployment sub show --name "<deployment-name>" --query "properties.outputs"

# Validate Bicep syntax
bicep lint bicep/main.bicep

# List resource groups
az group list --query "[?contains(name,'webapp')].name" -o table
```

---

**Last Updated:** 2025-01-XX  
**Version:** 1.0  
**Status:** Production Ready ✅
