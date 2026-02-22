# ============================================================================
# Azure OIDC Setup Script for GitHub Actions
# ============================================================================
# This script automates the complete OIDC configuration between GitHub Actions
# and Azure, including:
# - App registration creation
# - Service principal creation with RBAC assignments
# - Federated identity credentials for branch-based deployments
# - GitHub repository secrets configuration
#
# Prerequisites:
# - Azure CLI installed and logged in (az login)
# - GitHub CLI installed and authenticated (gh auth login)
# - Appropriate permissions in Azure (Application Administrator or Global Admin)
# - Admin access to GitHub repository
#
# Usage: .\setup-oidc.ps1
# ============================================================================

# Configuration Variables
$SubscriptionId = "934600ac-0f19-44b8-b439-b4c5f02d8a7d"
$GitHubOrg = "BenTheCloudGuy"
$RepoName = "msftlabs-bicep-webapp-demo"
$AppName = "github-actions-webapp-demo"

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "Azure OIDC Setup for GitHub Actions" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Subscription ID: $SubscriptionId"
Write-Host "  GitHub Org: $GitHubOrg"
Write-Host "  Repository: $RepoName"
Write-Host "  App Name: $AppName"
Write-Host ""

# ============================================================================
# Step 1: Verify Prerequisites
# ============================================================================
Write-Host "Step 1: Verifying prerequisites..." -ForegroundColor Cyan

# Check Azure CLI
try {
    $azVersion = az version --output json 2>$null | ConvertFrom-Json
    Write-Host "  ✓ Azure CLI installed: $($azVersion.'azure-cli')" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Azure CLI not found. Please install from: https://aka.ms/installazurecliwindows" -ForegroundColor Red
    exit 1
}

# Check GitHub CLI
try {
    $ghVersion = gh --version 2>$null | Select-Object -First 1
    Write-Host "  ✓ GitHub CLI installed: $ghVersion" -ForegroundColor Green
} catch {
    Write-Host "  ✗ GitHub CLI not found. Please install from: https://cli.github.com/" -ForegroundColor Red
    exit 1
}

# Check Azure login status
Write-Host "  Checking Azure authentication..." -ForegroundColor Yellow
$azAccount = az account show 2>$null | ConvertFrom-Json
if (-not $azAccount) {
    Write-Host "  ✗ Not logged into Azure. Running 'az login'..." -ForegroundColor Yellow
    az login
    $azAccount = az account show | ConvertFrom-Json
}
Write-Host "  ✓ Logged into Azure as: $($azAccount.user.name)" -ForegroundColor Green
Write-Host "  ✓ Current subscription: $($azAccount.name)" -ForegroundColor Green

# Set the target subscription
Write-Host "  Setting target subscription..." -ForegroundColor Yellow
az account set --subscription $SubscriptionId
Write-Host "  ✓ Subscription set to: $SubscriptionId" -ForegroundColor Green

# Check GitHub authentication
Write-Host "  Checking GitHub authentication..." -ForegroundColor Yellow
$ghAuth = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ✗ Not logged into GitHub. Running 'gh auth login'..." -ForegroundColor Yellow
    gh auth login
}
Write-Host "  ✓ Logged into GitHub" -ForegroundColor Green

Write-Host ""

# ============================================================================
# Step 2: Create Azure App Registration
# ============================================================================
Write-Host "Step 2: Creating Azure App Registration..." -ForegroundColor Cyan

# Check if app already exists
$existingApp = az ad app list --display-name $AppName --query "[0]" | ConvertFrom-Json
if ($existingApp) {
    Write-Host "  ⚠ App registration '$AppName' already exists" -ForegroundColor Yellow
    Write-Host "    App ID: $($existingApp.appId)" -ForegroundColor Yellow
    $response = Read-Host "  Do you want to use the existing app? (Y/N)"
    if ($response -ne "Y" -and $response -ne "y") {
        Write-Host "  Please delete the existing app or choose a different name" -ForegroundColor Red
        exit 1
    }
    $AppId = $existingApp.appId
    $AppObjectId = $existingApp.id
} else {
    # Create new app registration
    Write-Host "  Creating app registration '$AppName'..." -ForegroundColor Yellow
    az ad app create --display-name $AppName | Out-Null
    
    # Get app details
    Start-Sleep -Seconds 3
    $app = az ad app list --display-name $AppName --query "[0]" | ConvertFrom-Json
    $AppId = $app.appId
    $AppObjectId = $app.id
    
    Write-Host "  ✓ App registration created" -ForegroundColor Green
}

Write-Host "  Application ID: $AppId" -ForegroundColor Green
Write-Host "  Object ID: $AppObjectId" -ForegroundColor Green

# ============================================================================
# Step 3: Create Service Principal
# ============================================================================
Write-Host ""
Write-Host "Step 3: Creating Service Principal..." -ForegroundColor Cyan

# Check if service principal exists
$existingSp = az ad sp list --filter "appId eq '$AppId'" --query "[0]" | ConvertFrom-Json
if ($existingSp) {
    Write-Host "  ⚠ Service principal already exists" -ForegroundColor Yellow
    $SpObjectId = $existingSp.id
} else {
    Write-Host "  Creating service principal..." -ForegroundColor Yellow
    az ad sp create --id $AppId | Out-Null
    Start-Sleep -Seconds 3
    $sp = az ad sp list --filter "appId eq '$AppId'" --query "[0]" | ConvertFrom-Json
    $SpObjectId = $sp.id
    Write-Host "  ✓ Service principal created" -ForegroundColor Green
}

Write-Host "  Service Principal Object ID: $SpObjectId" -ForegroundColor Green

# ============================================================================
# Step 4: Assign RBAC Roles
# ============================================================================
Write-Host ""
Write-Host "Step 4: Assigning RBAC roles..." -ForegroundColor Cyan

# Check existing role assignments
$existingRoles = az role assignment list --assignee $AppId --scope "/subscriptions/$SubscriptionId" --query "[].roleDefinitionName" -o json | ConvertFrom-Json

# Assign Contributor role
if ($existingRoles -contains "Contributor") {
    Write-Host "  ⚠ Contributor role already assigned" -ForegroundColor Yellow
} else {
    Write-Host "  Assigning Contributor role..." -ForegroundColor Yellow
    az role assignment create `
        --assignee $AppId `
        --role "Contributor" `
        --scope "/subscriptions/$SubscriptionId" | Out-Null
    Write-Host "  ✓ Contributor role assigned" -ForegroundColor Green
}

# Optionally assign User Access Administrator role
Write-Host "  Assigning User Access Administrator role (for RBAC assignments)..." -ForegroundColor Yellow
if ($existingRoles -contains "User Access Administrator") {
    Write-Host "  ⚠ User Access Administrator role already assigned" -ForegroundColor Yellow
} else {
    az role assignment create `
        --assignee $AppId `
        --role "User Access Administrator" `
        --scope "/subscriptions/$SubscriptionId" | Out-Null
    Write-Host "  ✓ User Access Administrator role assigned" -ForegroundColor Green
}

# Verify role assignments
Write-Host ""
Write-Host "  Current role assignments:" -ForegroundColor Yellow
az role assignment list --assignee $AppId --scope "/subscriptions/$SubscriptionId" --query "[].{Role:roleDefinitionName, Scope:scope}" -o table

# ============================================================================
# Step 5: Create Federated Identity Credentials
# ============================================================================
Write-Host ""
Write-Host "Step 5: Creating federated identity credentials..." -ForegroundColor Cyan

# Check existing credentials
$existingCreds = az ad app federated-credential list --id $AppObjectId | ConvertFrom-Json

# Helper function to create or update federated credential
function Set-FederatedCredential {
    param(
        [string]$Name,
        [string]$Subject,
        [string]$Description
    )
    
    $existing = $existingCreds | Where-Object { $_.name -eq $Name }
    if ($existing) {
        Write-Host "  ⚠ Credential '$Name' already exists" -ForegroundColor Yellow
        # Optionally delete and recreate
        $response = Read-Host "    Update existing credential? (Y/N)"
        if ($response -eq "Y" -or $response -eq "y") {
            az ad app federated-credential delete --id $AppObjectId --federated-credential-id $Name --yes 2>$null
            Start-Sleep -Seconds 2
        } else {
            return
        }
    }
    
    Write-Host "  Creating credential '$Name'..." -ForegroundColor Yellow
    
    $params = @{
        name = $Name
        issuer = "https://token.actions.githubusercontent.com"
        subject = $Subject
        description = $Description
        audiences = @("api://AzureADTokenExchange")
    } | ConvertTo-Json -Compress
    
    az ad app federated-credential create --id $AppObjectId --parameters $params | Out-Null
    Write-Host "  ✓ Credential '$Name' created" -ForegroundColor Green
}

# Create credentials for each branch
Set-FederatedCredential `
    -Name "github-main-branch" `
    -Subject "repo:$GitHubOrg/${RepoName}:ref:refs/heads/main" `
    -Description "GitHub Actions - Main Branch (Production)"

Set-FederatedCredential `
    -Name "github-dev-branch" `
    -Subject "repo:$GitHubOrg/${RepoName}:ref:refs/heads/dev" `
    -Description "GitHub Actions - Dev Branch"

Set-FederatedCredential `
    -Name "github-qa-branch" `
    -Subject "repo:$GitHubOrg/${RepoName}:ref:refs/heads/qa" `
    -Description "GitHub Actions - QA Branch"

Set-FederatedCredential `
    -Name "github-pull-requests" `
    -Subject "repo:$GitHubOrg/${RepoName}:pull_request" `
    -Description "GitHub Actions - Pull Requests"

# Verify federated credentials
Write-Host ""
Write-Host "  Federated credentials configured:" -ForegroundColor Yellow
az ad app federated-credential list --id $AppObjectId --query "[].{Name:name, Subject:subject}" -o table

# ============================================================================
# Step 6: Get Azure Identity Information
# ============================================================================
Write-Host ""
Write-Host "Step 6: Gathering Azure identity information..." -ForegroundColor Cyan

$TenantId = az account show --query tenantId -o tsv

Write-Host "  ✓ Application (Client) ID: $AppId" -ForegroundColor Green
Write-Host "  ✓ Tenant ID: $TenantId" -ForegroundColor Green
Write-Host "  ✓ Subscription ID: $SubscriptionId" -ForegroundColor Green

# ============================================================================
# Step 7: Configure GitHub Repository Secrets
# ============================================================================
Write-Host ""
Write-Host "Step 7: Configuring GitHub repository secrets..." -ForegroundColor Cyan

# Set repository context
$repoContext = "$GitHubOrg/$RepoName"

Write-Host "  Setting secrets for repository: $repoContext" -ForegroundColor Yellow

# Set AZURE_CLIENT_ID
Write-Host "  Setting AZURE_CLIENT_ID..." -ForegroundColor Yellow
gh secret set AZURE_CLIENT_ID --body $AppId --repo $repoContext
Write-Host "  ✓ AZURE_CLIENT_ID set" -ForegroundColor Green

# Set AZURE_TENANT_ID
Write-Host "  Setting AZURE_TENANT_ID..." -ForegroundColor Yellow
gh secret set AZURE_TENANT_ID --body $TenantId --repo $repoContext
Write-Host "  ✓ AZURE_TENANT_ID set" -ForegroundColor Green

# Set AZURE_SUBSCRIPTION_ID
Write-Host "  Setting AZURE_SUBSCRIPTION_ID..." -ForegroundColor Yellow
gh secret set AZURE_SUBSCRIPTION_ID --body $SubscriptionId --repo $repoContext
Write-Host "  ✓ AZURE_SUBSCRIPTION_ID set" -ForegroundColor Green

# Verify secrets
Write-Host ""
Write-Host "  Verifying configured secrets:" -ForegroundColor Yellow
gh secret list --repo $repoContext

# ============================================================================
# Summary
# ============================================================================
Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Azure Configuration:" -ForegroundColor Yellow
Write-Host "  App Registration: $AppName"
Write-Host "  Application ID: $AppId"
Write-Host "  Tenant ID: $TenantId"
Write-Host "  Subscription ID: $SubscriptionId"
Write-Host ""
Write-Host "RBAC Assignments:" -ForegroundColor Yellow
Write-Host "  ✓ Contributor (subscription level)"
Write-Host "  ✓ User Access Administrator (subscription level)"
Write-Host ""
Write-Host "Federated Credentials:" -ForegroundColor Yellow
Write-Host "  ✓ github-main-branch (production)"
Write-Host "  ✓ github-dev-branch"
Write-Host "  ✓ github-qa-branch"
Write-Host "  ✓ github-pull-requests"
Write-Host ""
Write-Host "GitHub Secrets:" -ForegroundColor Yellow
Write-Host "  ✓ AZURE_CLIENT_ID"
Write-Host "  ✓ AZURE_TENANT_ID"
Write-Host "  ✓ AZURE_SUBSCRIPTION_ID"
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Create environment branches (dev, qa) if not already created"
Write-Host "  2. Push changes to trigger workflows"
Write-Host "  3. Monitor GitHub Actions for successful OIDC authentication"
Write-Host ""
Write-Host "Documentation:" -ForegroundColor Yellow
Write-Host "  - Quick Start: QUICKSTART.md"
Write-Host "  - Detailed Setup: SETUP.md"
Write-Host "  - OIDC Guide: .github/OIDC-AUTHENTICATION.md"
Write-Host "  - Secrets Reference: .github/SECRETS-REFERENCE.md"
Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan
