metadata name = 'Private DNS Zone Module'
metadata description = 'Deploys Azure Private DNS Zone with VNet link'
metadata owner = 'BenTheBuilder'

targetScope = 'resourceGroup'

// ============ //
// Parameters   //
// ============ //

@description('Required. Name of the Private DNS Zone.')
param zoneName string

@description('Optional. Tags for the DNS zone.')
param tags object = {}

@description('Required. VNet ID to link to the DNS zone.')
param vnetId string

@description('Optional. Enable auto registration.')
param enableAutoRegistration bool = false

// ==================== //
// Private DNS Zone     //
// ==================== //

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: zoneName
  location: 'global'
  tags: tags
  properties: {}
}

// VNet Link
resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZone
  name: '${zoneName}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: enableAutoRegistration
    virtualNetwork: {
      id: vnetId
    }
  }
}

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the Private DNS Zone.')
output resourceId string = privateDnsZone.id

@description('The name of the Private DNS Zone.')
output name string = privateDnsZone.name
