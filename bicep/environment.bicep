metadata name = 'Environment Resources'
metadata description = 'Deploys environment-specific resources (dev/qa/prod)'
metadata owner = 'BenTheBuilder'

targetScope = 'resourceGroup'

// ============ //
// Parameters   //
// ============ //

@description('Required. Azure region for deployment.')
param location string

@description('Required. Environment identifier.')
@allowed([
  'dev'
  'qa'
  'prod'
])
param environment string

@description('Required. Workload name.')
param workloadName string

@description('Optional. Deployment timestamp passed from GitHub Actions.')
param deployedDate string = ''!

@description('Optional. Deploying user passed from GitHub Actions.')
param deployedBy string = ''!

@description('Required. Resource tags.')
param tags object

@description('Required. Environment VNet address space.')
param envVnetAddressSpace string

@description('Required. Log Analytics Workspace Resource ID.')
param logAnalyticsWorkspaceId string

@description('Required. Log Analytics Workspace Name.')
param logAnalyticsWorkspaceName string

@description('Required. Networking resource group name.')
param networkingResourceGroupName string

@description('Optional. Management VNet ID for peering.')
param mgmtVnetId string = ''

// ============ //
// Variables    //
// ============ //

var envVnetName = 'vnet-${workloadName}-${environment}'
var keyVaultName = 'kv-${workloadName}-${environment}-${uniqueString(resourceGroup().id)}'
var webAppName = 'app-${workloadName}-${environment}-${uniqueString(resourceGroup().id)}'
var appServicePlanName = 'asp-${workloadName}-${environment}'

// Subnet configuration: Split /24 into two /25 subnets
var privateEndpointSubnetPrefix = cidrSubnet(envVnetAddressSpace, 25, 0) // First /25
var appServiceSubnetPrefix = cidrSubnet(envVnetAddressSpace, 25, 1)      // Second /25

var subnets = [
  {
    name: 'PrivateEndpoints'
    addressPrefix: privateEndpointSubnetPrefix
    nsg: false
    delegations: []
  }
  {
    name: 'AppServices'
    addressPrefix: appServiceSubnetPrefix
    nsg: true
    delegations: [
      {
        name: 'Microsoft.Web.serverFarms'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
      }
    ]
  }
]

// ===================== //
// Environment Network   //
// ===================== //

module envVnet './modules/virtualnetwork/main.bicep' = {
  name: 'deploy-env-vnet-${uniqueString(resourceGroup().id)}'
  scope: resourceGroup(networkingResourceGroupName)
  params: {
    name: envVnetName
    location: location
    tags: tags
    addressPrefixes: [envVnetAddressSpace]
    subnets: subnets
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

// VNet Peering to Management VNet (if provided)
module vnetPeering './modules/virtualnetwork/peering.bicep' = if (!empty(mgmtVnetId)) {
  name: 'deploy-vnet-peering-${uniqueString(resourceGroup().id)}'
  scope: resourceGroup(networkingResourceGroupName)
  params: {
    localVnetName: envVnet.outputs.name
    remoteVnetId: mgmtVnetId
    peeringName: 'peer-${environment}-to-mgmt'
  }
}

// =============== //
// Key Vault       //
// =============== //

module keyVault './modules/keyvault/main.bicep' = {
  name: 'deploy-keyvault-${uniqueString(resourceGroup().id)}'
  params: {
    name: keyVaultName
    location: location
    tags: tags
    enableRbacAuthorization: true
    publicNetworkAccess: 'Disabled'
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    privateEndpointSubnetId: envVnet.outputs.subnetIds[0] // PrivateEndpoints subnet
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

// ====================== //
// App Service Plan       //
// ====================== //

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: environment == 'prod' ? 'P1v3' : 'B1'
    tier: environment == 'prod' ? 'PremiumV3' : 'Basic'
    size: environment == 'prod' ? 'P1v3' : 'B1'
    family: environment == 'prod' ? 'Pv3' : 'B'
    capacity: environment == 'prod' ? 2 : 1
  }
  kind: 'linux'
  properties: {
    reserved: true
    zoneRedundant: environment == 'prod' ? true : false
  }
}

// Diagnostic Settings for App Service Plan
resource aspDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: appServicePlan
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// =============== //
// Web App         //
// =============== //

module webApp './modules/webapp/main.bicep' = {
  name: 'deploy-webapp-${uniqueString(resourceGroup().id)}'
  params: {
    name: webAppName
    location: location
    tags: tags
    appServicePlanId: appServicePlan.id
    runtimeStack: 'NODE|18-lts'
    httpsOnly: true
    publicNetworkAccess: 'Disabled'
    vnetIntegrationSubnetId: envVnet.outputs.subnetIds[1] // AppServices subnet
    privateEndpointSubnetId: envVnet.outputs.subnetIds[0] // PrivateEndpoints subnet
    keyVaultName: keyVault.outputs.name
    appSettings: {
      ENVIRONMENT: environment
      KEY_VAULT_NAME: keyVault.outputs.name
      WEBSITE_NODE_DEFAULT_VERSION: '~18'
      SCM_DO_BUILD_DURING_DEPLOYMENT: 'true'
    }
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

// Grant Web App access to Key Vault
module kvRoleAssignment './modules/keyvault/rbac.bicep' = {
  name: 'deploy-kv-rbac-${uniqueString(resourceGroup().id)}'
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: webApp.outputs.principalId
    roleDefinitionId: '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
  }
}

// Grant Web App access to Log Analytics (for custom logs/metrics)
module logAnalyticsRoleAssignment './modules/loganalytics/rbac.bicep' = {
  name: 'deploy-la-rbac-${uniqueString(resourceGroup().id)}'
  params: {
    workspaceName: logAnalyticsWorkspaceName
    principalId: webApp.outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: '92aaf0da-9dab-42b6-94a3-d43ce8d16293' // Log Analytics Contributor
    roleDescription: 'Allow Web App to send custom logs and metrics to Log Analytics'
  }
}

// Store demo secrets in Key Vault
resource kvExisting 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: 'kv-${location}-${environment}-${workloadName}'
}

resource secretDemo 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kvExisting
  name: 'demo-secret'
  properties: {
    value: 'This is a secret from ${environment} Key Vault! Deployed on ${deployedDate} by ${deployedBy}'
    contentType: 'text/plain'
  }
  dependsOn: [
    keyVault
  ]
}

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the environment VNet.')
output envVnetId string = envVnet.outputs.resourceId

@description('The name of the environment VNet.')
output envVnetName string = envVnet.outputs.name

@description('The resource ID of the Key Vault.')
output keyVaultId string = keyVault.outputs.resourceId

@description('The name of the Key Vault.')
output keyVaultName string = keyVault.outputs.name

@description('The resource ID of the Web App.')
output webAppId string = webApp.outputs.resourceId

@description('The name of the Web App.')
output webAppName string = webApp.outputs.name

@description('The default hostname of the Web App.')
output webAppDefaultHostname string = webApp.outputs.defaultHostname

@description('The principal ID of the Web App managed identity.')
output webAppPrincipalId string = webApp.outputs.principalId
