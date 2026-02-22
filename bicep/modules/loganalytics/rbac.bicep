metadata name = 'Log Analytics RBAC Module'
metadata description = 'Assigns RBAC roles to Log Analytics Workspace using Azure IAM'
metadata owner = 'BenTheBuilder'

targetScope = 'resourceGroup'

// ============ //
// Parameters   //
// ============ //

@description('Required. Name of the Log Analytics Workspace.')
param workspaceName string

@description('Required. Principal ID to assign the role to.')
param principalId string

@description('Required. Role definition ID. Common built-in roles: Log Analytics Contributor (92aaf0da-9dab-42b6-94a3-d43ce8d16293), Log Analytics Reader (73c42c96-874c-492a-8b58-c20b4869654e), Monitoring Contributor (749f88d5-cbae-40b8-bcfc-e573ddc772fa), Monitoring Reader (43d0d8ad-25c7-4714-9337-8ba259a9fe05)')
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
param roleDescription string = 'RBAC assignment for Log Analytics Workspace access using Azure IAM'

// ==================== //
// Resources            //
// ==================== //

resource workspace 'Microsoft.OperationalInsights/workspaces@2025-07-01' existing = {
  name: workspaceName
}

// RBAC assignment using Azure IAM
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(workspace.id, principalId, roleDefinitionId)
  scope: workspace
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

@description('The principal ID that was granted access.')
output principalId string = principalId

@description('The role definition ID that was assigned.')
output roleDefinitionId string = roleDefinitionId
