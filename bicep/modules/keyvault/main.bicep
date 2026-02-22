metadata name = 'Key Vault Module'
metadata description = 'Deploys Azure Key Vault with RBAC authentication (no access policies) and private endpoint'
metadata owner = 'BenTheBuilder'

targetScope = 'resourceGroup'

// ============================================ //
// RBAC Best Practices for Azure Key Vault     //
// ============================================ //
// This module uses Azure RBAC for Key Vault access control instead of legacy access policies.
// Benefits:
// - Unified Azure IAM model across all resources
// - Better integration with Azure AD PIM (Privileged Identity Management)
// - Easier to audit and manage at scale
// - Supports managed identities natively
//
// Common Key Vault RBAC roles:
// - Key Vault Administrator: 00482a5a-887f-4fb3-b363-3b7fe8e74483 (full access)
// - Key Vault Secrets User: 4633458b-17de-408a-b874-0445c86b69e6 (read secrets)
// - Key Vault Secrets Officer: b86a8fe4-44ce-4948-aee5-eccb2c155cd7 (manage secrets)
// - Key Vault Crypto Officer: 14b46e9e-c2b7-41b4-b07b-48a6ebf60603 (crypto operations)
// - Key Vault Certificates Officer: a4417e6f-fecd-4de8-b567-7b0420556985 (manage certificates)
//
// For role assignments, use the separate rbac.bicep module

// ============ //
// Parameters   //
// ============ //

@description('Required. Name of the Key Vault.')
@maxLength(24)
param name string

@description('Optional. Location for the Key Vault.')
param location string = resourceGroup().location

@description('Optional. Tags for the Key Vault.')
param tags object = {}

@description('Optional. Enable RBAC authorization.')
param enableRbacAuthorization bool = true

@description('Optional. Enable soft delete.')
param enableSoftDelete bool = true

@description('Optional. Soft delete retention in days.')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90

@description('Optional. Enable purge protection.')
param enablePurgeProtection bool = true

@description('Optional. Public network access.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Disabled'

@description('Optional. Enabled for deployment.')
param enabledForDeployment bool = false

@description('Optional. Enabled for template deployment.')
param enabledForTemplateDeployment bool = false

@description('Optional. Enabled for disk encryption.')
param enabledForDiskEncryption bool = false

@description('Optional. Private endpoint subnet ID.')
param privateEndpointSubnetId string = ''

@description('Optional. Log Analytics Workspace ID.')
param logAnalyticsWorkspaceId string = ''

// ==================== //
// Variables            //
// ==================== //

var hasPrivateEndpoint = !empty(privateEndpointSubnetId)
var hasLogAnalytics = !empty(logAnalyticsWorkspaceId)

// ==================== //
// Key Vault            //
// ==================== //

// Key Vault with RBAC enabled (no access policies)
resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: enableRbacAuthorization  // Uses Azure IAM instead of access policies
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: enablePurgeProtection ? true : null
    publicNetworkAccess: publicNetworkAccess
    enabledForDeployment: enabledForDeployment
    enabledForTemplateDeployment: enabledForTemplateDeployment
    enabledForDiskEncryption: enabledForDiskEncryption
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: publicNetworkAccess == 'Disabled' ? 'Deny' : 'Allow'
      ipRules: []
      virtualNetworkRules: []
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
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

// Diagnostic Settings
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (hasLogAnalytics) {
  name: 'default'
  scope: keyVault
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

// Resource lock
resource lock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: '${name}-lock'
  scope: keyVault
  properties: {
    level: 'CanNotDelete'
    notes: 'Prevents accidental deletion of Key Vault'
  }
}

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the Key Vault.')
output resourceId string = keyVault.id

@description('The name of the Key Vault.')
output name string = keyVault.name

@description('The URI of the Key Vault.')
output vaultUri string = keyVault.properties.vaultUri

@description('The resource ID of the private endpoint.')
output privateEndpointId string = hasPrivateEndpoint ? privateEndpoint.id : ''
