metadata name = 'Application Gateway Module'
metadata description = 'Deploys Azure Application Gateway with WAF'
metadata owner = 'BenTheBuilder'

targetScope = 'resourceGroup'

// ============ //
// Parameters   //
// ============ //

@description('Required. Name of the Application Gateway.')
param name string

@description('Optional. Location for the App Gateway.')
param location string = resourceGroup().location

@description('Optional. Tags for the App Gateway.')
param tags object = {}

@description('Required. Subnet ID for the Application Gateway.')
param subnetId string

@description('Optional. SKU name.')
@allowed([
  'Standard_v2'
  'WAF_v2'
])
param sku string = 'WAF_v2'

@description('Optional. Capacity (instance count).')
@minValue(1)
@maxValue(10)
param capacity int = 2

@description('Optional. Log Analytics Workspace ID.')
param logAnalyticsWorkspaceId string = ''

// ==================== //
// Variables            //
// ==================== //

var hasLogAnalytics = !empty(logAnalyticsWorkspaceId)
var publicIpName = '${name}-pip'

// ==================== //
// Public IP            //
// ==================== //

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: publicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// ======================== //
// Application Gateway      //
// ======================== //

resource appGateway 'Microsoft.Network/applicationGateways@2025-01-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: sku
      tier: sku
      capacity: capacity
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGatewayFrontendIP'
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
      {
        name: 'port_443'
        properties: {
          port: 443
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'defaultBackendPool'
        properties: {
          backendAddresses: []
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'defaultHttpSettings'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
          pickHostNameFromBackendAddress: true
        }
      }
    ]
    httpListeners: [
      {
        name: 'defaultHttpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', name, 'appGatewayFrontendIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', name, 'port_80')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'defaultRoutingRule'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', name, 'defaultHttpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', name, 'defaultBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', name, 'defaultHttpSettings')
          }
        }
      }
    ]
    webApplicationFirewallConfiguration: sku == 'WAF_v2' ? {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
      disabledRuleGroups: []
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    } : null
  }
}

// Diagnostic Settings
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (hasLogAnalytics) {
  name: 'default'
  scope: appGateway
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

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the Application Gateway.')
output resourceId string = appGateway.id

@description('The name of the Application Gateway.')
output name string = appGateway.name

@description('The public IP address.')
output publicIpAddress string = publicIp.properties.ipAddress
