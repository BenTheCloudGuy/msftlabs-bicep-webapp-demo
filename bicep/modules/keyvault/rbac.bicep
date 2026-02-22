metadata name = 'Key Vault RBAC Module'
metadata description = 'Assigns RBAC role to Key Vault using Azure IAM'
metadata owner = 'BenTheBuilder'

targetScope = 'resourceGroup'

// ============ //
// Parameters   //
// ============ //

@description('Required. Name of the Key Vault.')
param keyVaultName string

@description('Required. Principal ID to assign the role to.')
param principalId string

@description('Required. Role definition ID or name. Common built-in roles: Key Vault Administrator (00482a5a-887f-4fb3-b363-3b7fe8e74483), Key Vault Secrets User (4633458b-17de-408a-b874-0445c86b69e6), Key Vault Secrets Officer (b86a8fe4-44ce-4948-aee5-eccb2c155cd7), Key Vault Crypto Officer (14b46e9e-c2b7-41b4-b07b-48a6ebf60603)')
param roleDefinitionId string

@description('Optional. Principal type.')
@allowed([
  'ServicePrincipal'
  'User'
  'Group'
  'Device'
  'ForeignGroup'
])
param principalType string = 'ServicePrincipal'

@description('Optional. Description for the role assignment.')
param roleDescription string = 'RBAC assignment for Key Vault access using Azure IAM'

// ==================== //
// Resources            //
// ==================== //

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  name: keyVaultName
}

// RBAC assignment using Azure IAM (no access policies required)
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, principalId, roleDefinitionId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: principalType
    description: roleDescription
  }
}

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the role assignment.')
output resourceId string = roleAssignment.id

@description('The name of the role assignment.')
output name string = roleAssignment.name
