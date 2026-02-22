# GitHub WebApp CI/CD Demo

This demo showcases best practices for CI/CD with Infrastructure as Code (IaC) using Bicep and GitHub Actions.

## Quick Links

- **[Quick Start Guide](QUICKSTART.md)** - Fast setup for experienced users (10 minutes)
- **[Detailed Setup Guide](SETUP.md)** - Step-by-step instructions with explanations
- **[OIDC Authentication Guide](.github/OIDC-AUTHENTICATION.md)** - How federated credentials work
- **[OIDC Setup Summary](OIDC-SETUP-SUMMARY.md)** - Current configuration details and verification
- **[Naming Standards Module](bicep/modules/naming/README.md)** - Enforce Azure CAF naming conventions

## Overview

This end-to-end demo includes:
- **Unit Testing** - Bicep linting, validation, and what-if analysis
- **Environment Gates** - Branch-based deployment (dev/qa/prod)
- **Pre-deployment Validation** - Validates infrastructure before deployment
- **Multi-Environment Setup** - Separate environments with proper isolation
- **Comprehensive Tagging** - Owner, Environment, DeployedDate, DeployedBy, Platform, Notes
- **Centralized Logging** - All resources send diagnostics to Log Analytics
- **Network Security** - Private endpoints, VNet integration, NSGs
- **Self-Hosted Runners** - Deploys VM with GitHub runner for secure deployments

## Architecture

### Common Management Resources (Production Only)
- **Log Analytics Workspace** - Centralized monitoring and diagnostics
- **Virtual Machine** - Ubuntu 22.04 hosting GitHub Self-Hosted Runner
- **Virtual Network** (10.90.0.0/22) - Management network with subnets for Bastion, DevOps, Public, Gateway
- **Application Gateway + WAF** - Centralized ingress for all environments
- **Private DNS Zones** - DNS resolution for private endpoints

### Environment-Specific Resources (Dev/QA/Prod)
- **Azure Web App** - NodeJS application with managed identity
- **Virtual Network** (10.90.x.0/24) - Environment network with PrivateEndpoint and AppService subnets
- **Key Vault** - Stores application secrets with private endpoint access
- **Network Security Groups** - Controls traffic flow
- **VNet Peering** - Connects environment networks to management network

## Repository Structure

```
demos/github-webapp-demo/
├── .github/
│   └── workflows/
│       ├── unit-tests.yml          # Runs on every PR
│       ├── deploy-dev.yml          # Deploys to dev on push to dev branch
│       ├── deploy-qa.yml           # Deploys to QA on push to qa branch
│       └── deploy-prod.yml         # Deploys to prod on push to main branch
├── bicep/
│   ├── main.bicep                  # Main orchestration template
│   ├── common-mgmt.bicep           # Common management resources
│   ├── environment.bicep           # Environment-specific resources
│   └── modules/
│       ├── loganalytics/           # Log Analytics Workspace module
│       ├── virtualnetwork/         # Virtual Network module
│       ├── vm/                     # Virtual Machine module
│       ├── appgateway/             # Application Gateway module
│       ├── webapp/                 # Web App module
│       ├── keyvault/               # Key Vault module
│       ├── nsg/                    # Network Security Group module
│       └── privatedns/             # Private DNS Zone module
├── parameters/
│   ├── dev.bicepparam             # Dev environment parameters
│   ├── qa.bicepparam              # QA environment parameters
│   └── prod.bicepparam            # Prod environment parameters
├── app/                            # NodeJS Web Application
│   ├── package.json
│   ├── server.js
│   └── views/
├── tests/
│   └── infrastructure.tests.ps1   # Pester tests for infrastructure
└── README.md                       # This file
```

## Prerequisites

- Azure Subscription with Contributor access
- GitHub repository with admin access
- Azure CLI installed ([Download](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
- Bicep CLI installed (`az bicep install`)
- GitHub CLI installed (optional, [Download](https://cli.github.com/))

### Required GitHub Secrets

This demo uses **OIDC (OpenID Connect)** for secure, passwordless authentication with Azure:

| Secret Name | Description |
|-------------|-------------|
| `AZURE_CLIENT_ID` | Application (client) ID from Azure App Registration |
| `AZURE_TENANT_ID` | Azure AD (Entra ID) tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target Azure subscription ID |

**Note**: No client secrets or passwords are stored with OIDC authentication.

For setup instructions, see:
- **[Quick Start Guide](QUICKSTART.md)** - Fast setup (10 minutes)
- **[Detailed Setup Guide](SETUP.md)** - Complete step-by-step instructions
- **[OIDC Authentication Guide](.github/OIDC-AUTHENTICATION.md)** - How it works

## GitHub Actions Workflows

### 1. Unit Tests (`unit-tests.yml`)
Runs on every pull request:
- Lints all Bicep files
- Validates Bicep syntax
- Runs `az deployment what-if` for all environments
- Executes Pester tests
- Comments results back to PR

### 2. Deploy to Dev (`deploy-dev.yml`)
Triggers on push to `dev` branch:
- Runs unit tests
- Validates deployment
- Deploys infrastructure to dev environment
- Deploys web application
- Runs smoke tests

### 3. Deploy to QA (`deploy-qa.yml`)
Triggers on push to `qa` branch:
- Runs unit tests
- Validates deployment
- Requires manual approval (environment protection)
- Deploys infrastructure to QA environment
- Deploys web application
- Runs integration tests

### 4. Deploy to Production (`deploy-prod.yml`)
Triggers on push to `main` branch:
- Runs unit tests
- Validates deployment
- Requires manual approval (environment protection)
- Deploys common management resources (if first deploy)
- Deploys production infrastructure
- Deploys web application
- Runs smoke and integration tests

## Resource Naming Convention

- Resource Groups: `rg-{region}-{environment}-{purpose}`
- Resources: `{workload}-{region}-{environment}-{resource-type}`
- Examples:
  - `rg-eastus-prod-mgmt-common`
  - `webapp-eastus-dev-app`
  - `kv-eastus-qa-secrets`

## Tags Applied to All Resources

```bicep
{
  Owner: 'BenTheBuilder'
  Environment: 'dev|qa|prod'
  DeployedDate: '2026-02-22T10:30:00Z'  // ISO 8601 format
  DeployedBy: 'githubusername'
  Platform: 'DemoApp'
  Notes: 'This is a DemoApp PoC - short lived!'
}
```

## Getting Started

### Quick Setup (10 minutes)

Follow the **[Quick Start Guide](QUICKSTART.md)** for a streamlined setup:
1. Create Azure App Registration with OIDC federated credentials
2. Configure GitHub repository secrets
3. Deploy to your first environment

### Detailed Setup

For step-by-step instructions with explanations, see the **[Detailed Setup Guide](SETUP.md)**.

### Basic Workflow

Once configured, the deployment workflow is:

```bash
# 1. Clone repository
git clone <repo-url>
cd msftlabs-bicep-webapp-demo

# 2. Create environment branches
git checkout -b dev
git push -u origin dev

git checkout -b qa  
git push -u origin qa

# 3. Push to trigger deployments
git checkout dev
echo "trigger deployment" >> README.md
git commit -am "Deploy to dev"
git push origin dev  # Triggers deploy-dev.yml workflow
```

### GitHub Environments (Optional but Recommended)

Create environments in **Settings** → **Environments** for deployment protection:

1. **development** - No protection rules
2. **qa** - Required reviewers + 5 minute wait timer  
3. **production** - Required reviewers + 30 minute wait timer

Learn more: [GitHub Environments Documentation](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)

---

## Testing

### Run Unit Tests Locally

```powershell
# Install Pester if not already installed
Install-Module -Name Pester -Force -SkipPublisherCheck

# Run infrastructure tests
Invoke-Pester -Path ./tests/infrastructure.tests.ps1
```

### Validate Bicep Files

```bash
# Lint all Bicep files
bicep build ./bicep/main.bicep

# Run what-if analysis
az deployment sub what-if \
  --location eastus \
  --template-file ./bicep/main.bicep \
  --parameters ./parameters/dev.bicepparam
```

## Troubleshooting

### Common Issues

1. **Deployment Failures**
   - Check Azure Activity Log
   - Review deployment errors in GitHub Actions logs
   - Verify RBAC permissions

2. **Network Connectivity**
   - Verify VNet peering is established
   - Check NSG rules
   - Validate private endpoint DNS resolution

3. **Application Issues**
   - Check App Service logs
   - Verify Key Vault access policies
   - Review Application Insights telemetry

## Security Considerations

- All resources use managed identities (no passwords)
- Web Apps accessible only via private endpoints
- Key Vault uses RBAC and private endpoints
- Network Security Groups control traffic flow
- Application Gateway provides WAF protection
- Diagnostic logs sent to Log Analytics Workspace

## Cost Optimization

- Resource locks prevent accidental deletion
- Resources tagged for cost tracking
- Consider scaling down non-production resources
- Review and clean up regularly

## Contributing

Please follow these guidelines when contributing:
1. Create feature branches from `dev`
2. Ensure all tests pass
3. Update documentation
4. Submit PR for review

## License

MIT License - See LICENSE file for details

## Support

For issues or questions, please create an issue in the GitHub repository.
