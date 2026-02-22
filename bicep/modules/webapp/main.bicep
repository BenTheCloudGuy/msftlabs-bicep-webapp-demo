metadata name = 'Web App Module'
metadata description = 'Deploys Azure Web App with SystemAssigned Managed Identity, VNet integration and private endpoint'
metadata owner = 'BenTheBuilder'

targetScope = 'resourceGroup'

// ============================================ //
// Managed Identity & RBAC Best Practices       //
// ============================================ //
// This module deploys a Web App with SystemAssigned Managed Identity.
// The managed identity eliminates the need for storing credentials and uses Azure IAM for authentication.
//
// Benefits of Managed Identities:
// - No credentials in code or configuration
// - Automatic credential rotation by Azure
// - Fine-grained access control using RBAC
// - Works with all Azure services that support Azure AD authentication
//
// The Web App's managed identity can be granted access to:
// - Key Vault (to read secrets)
// - Storage Accounts (to read/write data)
// - Databases (Azure SQL, Cosmos DB)
// - Service Bus, Event Hubs, etc.
//
// Use the keyvault/rbac.bicep or other RBAC modules to grant permissions

// ============ //
// Parameters   //
// ============ //

@description('Required. Name of the Web App.')
param name string

@description('Optional. Location for the Web App.')
param location string = resourceGroup().location

@description('Optional. Tags for the Web App.')
param tags object = {}

@description('Required. App Service Plan resource ID.')
param appServicePlanId string

@description('Required. Runtime stack (e.g., NODE|18-lts, PYTHON|3.11).')
param runtimeStack string

@description('Optional. Require HTTPS only.')
param httpsOnly bool = true

@description('Optional. Public network access.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Disabled'

@description('Optional. VNet integration subnet ID.')
param vnetIntegrationSubnetId string = ''

@description('Optional. Private endpoint subnet ID.')
param privateEndpointSubnetId string = ''

@description('Optional. Key Vault name for storing publish settings.')
param keyVaultName string = ''

@description('Optional. App settings.')
param appSettings object = {}

@description('Optional. Log Analytics Workspace ID.')
param logAnalyticsWorkspaceId string = ''

// ==================== //
// Variables            //
// ==================== //

var hasVnetIntegration = !empty(vnetIntegrationSubnetId)
var hasPrivateEndpoint = !empty(privateEndpointSubnetId)
var hasLogAnalytics = !empty(logAnalyticsWorkspaceId)

var defaultAppSettings = {
  WEBSITE_HTTPLOGGING_RETENTION_DAYS: '7'
  WEBSITES_ENABLE_APP_SERVICE_STORAGE: 'false'
}

var mergedAppSettings = union(defaultAppSettings, appSettings)

// ==================== //
// Web App              //
// ==================== //

resource webApp 'Microsoft.Web/sites@2025-03-01' = {
  name: name
  location: location
  tags: tags
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: httpsOnly
    publicNetworkAccess: publicNetworkAccess
    virtualNetworkSubnetId: hasVnetIntegration ? vnetIntegrationSubnetId : null
    outboundVnetRouting: hasVnetIntegration ? {
      allTraffic: true
    } : null
    siteConfig: {
      linuxFxVersion: runtimeStack
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      appSettings: [for item in items(mergedAppSettings): {
        name: item.key
        value: item.value
      }]
      healthCheckPath: '/health'
      httpLoggingEnabled: true
      detailedErrorLoggingEnabled: true
      requestTracingEnabled: true
    }
  }
}

// Private Endpoint
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-10-01' = if (hasPrivateEndpoint) {
  name: '${name}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-pe-connection'
        properties: {
          privateLinkServiceId: webApp.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
  }
}

// Diagnostic Settings
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (hasLogAnalytics) {
  name: 'default'
  scope: webApp
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Store publish profile in Key Vault (if provided)
resource publishProfileSecret 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = if (!empty(keyVaultName)) {
  name: '${keyVaultName}/${name}-publish-profile'
  properties: {
    value: list('${webApp.id}/config/publishingcredentials', '2025-03-01').properties.publishingPassword
    contentType: 'application/xml'
  }
}

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the Web App.')
output resourceId string = webApp.id

@description('The name of the Web App.')
output name string = webApp.name

@description('The default hostname of the Web App.')
output defaultHostname string = webApp.properties.defaultHostName

@description('The principal ID of the system-assigned managed identity.')
output principalId string = webApp.identity.principalId

@description('The resource ID of the private endpoint.')
output privateEndpointId string = hasPrivateEndpoint ? privateEndpoint.id : ''
