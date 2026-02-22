metadata name = 'VNet Peering Module'
metadata description = 'Creates VNet peering between two virtual networks'
metadata owner = 'BenTheBuilder'

targetScope = 'resourceGroup'

// ============ //
// Parameters   //
// ============ //

@description('Required. Name of the local VNet (in this resource group).')
param localVnetName string

@description('Required. Resource ID of the remote VNet.')
param remoteVnetId string

@description('Optional. Name for the peering.')
param peeringName string

@description('Optional. Allow virtual network access.')
param allowVirtualNetworkAccess bool = true

@description('Optional. Allow forwarded traffic.')
param allowForwardedTraffic bool = true

@description('Optional. Allow gateway transit.')
param allowGatewayTransit bool = false

@description('Optional. Use remote gateways.')
param useRemoteGateways bool = false

// ==================== //
// Resources            //
// ==================== //

resource localVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: localVnetName
}

resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: localVnet
  name: peeringName
  properties: {
    allowVirtualNetworkAccess: allowVirtualNetworkAccess
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: allowGatewayTransit
    useRemoteGateways: useRemoteGateways
    remoteVirtualNetwork: {
      id: remoteVnetId
    }
  }
}

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the peering.')
output resourceId string = peering.id

@description('The name of the peering.')
output name string = peering.name

@description('The peering state.')
output peeringState string = peering.properties.peeringState
