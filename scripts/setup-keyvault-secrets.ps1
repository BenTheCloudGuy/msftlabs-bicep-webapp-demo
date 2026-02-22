<#
.SYNOPSIS
    Sets up required KeyVault secrets for VM password management
.DESCRIPTION
    This script creates the KeyVault (if needed) and stores the VM admin password
    as a secret for use by the Bicep deployment.
.PARAMETER SubscriptionId
    Azure subscription ID
.PARAMETER ResourceGroupName
    Resource group name for the KeyVault
.PARAMETER KeyVaultName
    Name of the KeyVault
.PARAMETER Location
    Azure region
.PARAMETER VmAdminPassword
    The VM admin password to store
.EXAMPLE
    .\setup-keyvault-secrets.ps1 -SubscriptionId "934600ac-0f19-44b8-b439-b4c5f02d8a7d" `
        -ResourceGroupName "rg-centralus-prod-mgmt-common" `
        -KeyVaultName "kv-mgmt-prod-secrets" `
        -Location "centralus" `
        -VmAdminPassword (Read-Host -AsSecureString -Prompt "Enter VM Admin Password")
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$KeyVaultName,

    [Parameter(Mandatory = $true)]
    [string]$Location,

    [Parameter(Mandatory = $true)]
    [SecureString]$VmAdminPassword
)

# Set error action preference
$ErrorActionPreference = 'Stop'

Write-Host "🔐 Setting up KeyVault secrets for VM management..." -ForegroundColor Cyan

# Set subscription context
Write-Host "Setting subscription context to: $SubscriptionId" -ForegroundColor Yellow
az account set --subscription $SubscriptionId

# Check if resource group exists, create if not
Write-Host "Checking resource group: $ResourceGroupName" -ForegroundColor Yellow
$rg = az group show --name $ResourceGroupName --query "id" -o tsv 2>$null
if (-not $rg) {
    Write-Host "Creating resource group: $ResourceGroupName" -ForegroundColor Green
    az group create --name $ResourceGroupName --location $Location
} else {
    Write-Host "Resource group exists: $ResourceGroupName" -ForegroundColor Green
}

# Check if KeyVault exists, create if not
Write-Host "Checking KeyVault: $KeyVaultName" -ForegroundColor Yellow
$kv = az keyvault show --name $KeyVaultName --query "id" -o tsv 2>$null
if (-not $kv) {
    Write-Host "Creating KeyVault: $KeyVaultName" -ForegroundColor Green
    az keyvault create `
        --name $KeyVaultName `
        --resource-group $ResourceGroupName `
        --location $Location `
        --enable-rbac-authorization true `
        --enabled-for-deployment true `
        --enabled-for-template-deployment true
    
    # Get current user object ID
    $currentUserObjectId = az ad signed-in-user show --query "id" -o tsv
    
    # Assign Key Vault Administrator role to current user
    Write-Host "Assigning Key Vault Administrator role to current user" -ForegroundColor Green
    az role assignment create `
        --role "Key Vault Administrator" `
        --assignee $currentUserObjectId `
        --scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.KeyVault/vaults/$KeyVaultName"
    
    # Wait for RBAC propagation
    Write-Host "Waiting for RBAC propagation (30 seconds)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
} else {
    Write-Host "KeyVault exists: $KeyVaultName" -ForegroundColor Green
}

# Convert SecureString to plain text for Azure CLI
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($VmAdminPassword)
$plainTextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

# Store VM admin password in KeyVault
Write-Host "Storing VM admin password in KeyVault..." -ForegroundColor Yellow
az keyvault secret set `
    --vault-name $KeyVaultName `
    --name "vmAdminPassword" `
    --value $plainTextPassword `
    --description "VM Admin Password for self-hosted runner" `
    --output none

# Clear the plain text password from memory
$plainTextPassword = $null
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

Write-Host "✅ KeyVault secret setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Summary:" -ForegroundColor Cyan
Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "  KeyVault Name: $KeyVaultName" -ForegroundColor White
Write-Host "  Secret Name: vmAdminPassword" -ForegroundColor White
Write-Host "  Location: $Location" -ForegroundColor White
Write-Host ""
Write-Host "✨ You can now deploy using the parameter files:" -ForegroundColor Green
Write-Host "   - parameters/prod.bicepparam (for initial deployment with deployCommonMgmt = true)" -ForegroundColor White
Write-Host "   - parameters/dev.bicepparam" -ForegroundColor White
Write-Host "   - parameters/qa.bicepparam" -ForegroundColor White
