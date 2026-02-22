metadata name = 'Virtual Network Module'
metadata description = 'Deploys Azure Virtual Network with subnets and NSGs'
metadata owner = 'BenTheBuilder'

targetScope = 'resourceGroup'

// ============ //
// Parameters   //
// ============ //

@description('Required. Name of the Virtual Network.')
param name string

@description('Optional. Location for the VNet.')
param location string = resourceGroup().location

@description('Optional. Tags for the VNet.')
param tags object = {}

@description('Required. Address prefixes for the VNet.')
param addressPrefixes array

@description('Required. Subnets configuration.')
param subnets array

@description('Optional. Enable DDoS protection.')
param enableDdosProtection bool = false

@description('Optional. Enable VM protection.')
param enableVmProtection bool = false

@description('Optional. Log Analytics Workspace ID for diagnostics.')
param logAnalyticsWorkspaceId string = ''

// ==================== //
// Variables            //
// ==================== //

var hasLogAnalytics = !empty(logAnalyticsWorkspaceId)

// ==================== //
// Network Security Groups //
// ==================== //

resource nsgs 'Microsoft.Network/networkSecurityGroups@2024-05-01' = [for subnet in subnets: if (subnet.nsg) {
  name: 'nsg-${subnet.name}'
  location: location
  tags: tags
  properties: {
    securityRules: subnet.name == 'DevOpsRunners' ? [
      {
        name: 'Allow-HTTPS-Outbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          description: 'Allow HTTPS outbound for GitHub connectivity'
        }
      }
      {
        name: 'Allow-AzureCloud-Outbound'
        properties: {
          priority: 110
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud'
          description: 'Allow Azure services'
        }
      }
    ] : subnet.name == 'AppServices' ? [
      {
        name: 'Allow-HTTPS-Outbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          description: 'Allow HTTPS outbound'
        }
      }
      {
        name: 'Allow-HTTP-Outbound'
        properties: {
          priority: 110
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          description: 'Allow HTTP outbound'
        }
      }
      {
        name: 'Allow-SQL-Outbound'
        properties: {
          priority: 120
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Sql'
          description: 'Allow SQL outbound if needed'
        }
      }
    ] : []
  }
}]

// NSG Diagnostic Settings
resource nsgDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (subnet, i) in subnets: if (subnet.nsg && hasLogAnalytics) {
  name: 'default'
  scope: nsgs[i]
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}]

// ==================== //
// Virtual Network      //
// ==================== //

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    enableDdosProtection: enableDdosProtection
    enableVmProtection: enableVmProtection
    subnets: [for (subnet, i) in subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        networkSecurityGroup: subnet.nsg ? {
          id: nsgs[i].id
        } : null
        delegations: subnet.?delegations ?? []
        privateEndpointNetworkPolicies: subnet.name == 'PrivateEndpoints' ? 'Disabled' : 'Enabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
    }]
  }
}

// VNet Diagnostic Settings
resource vnetDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (hasLogAnalytics) {
  name: 'default'
  scope: vnet
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
  scope: vnet
  properties: {
    level: 'CanNotDelete'
    notes: 'Prevents accidental deletion of Virtual Network'
  }
}

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the Virtual Network.')
output resourceId string = vnet.id

@description('The name of the Virtual Network.')
output name string = vnet.name

@description('The resource IDs of all subnets.')
output subnetIds array = [for (subnet, i) in subnets: vnet.properties.subnets[i].id]

@description('The names of all subnets.')
output subnetNames array = [for subnet in subnets: subnet.name]

@description('The resource IDs of NSGs.')
output nsgIds array = [for (subnet, i) in subnets: subnet.nsg ? nsgs[i].id : '']
