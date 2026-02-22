metadata name = 'Common Management Resources'
metadata description = 'Deploys shared management resources for all environments'
metadata owner = 'BenTheBuilder'

targetScope = 'resourceGroup'

// ============ //
// Parameters   //
// ============ //

@description('Required. Azure region for deployment.')
param location string

@description('Required. Workload name.')
param workloadName string

@description('Optional. Deployment timestamp passed from GitHub Actions.')
param deployedDate string = ''!

@description('Optional. Deploying user passed from GitHub Actions.')
param deployedBy string = ''!

@description('Required. Resource tags.')
param tags object

@description('Required. Management VNet address space.')
param mgmtVnetAddressSpace string

@description('Required. Networking resource group name.')
param networkingResourceGroupName string

@description('Optional. Deploy Application Gateway.')
param deployAppGateway bool = false

@description('Optional. Deploy self-hosted runner VM.')
param deploySelfHostedRunner bool = false

@description('Optional. VM admin username.')
@secure()
param vmAdminUsername string = ''

@description('Optional. Key Vault name where VM admin password is stored.')
param keyVaultName string = ''

// ============ //
// Variables    //
// ============ //

var lawName = 'core-law'
var vmName = 'vm-runner-prod'
var mgmtVnetName = 'vnet-mgmt-prod'

// Add deployment metadata to tags for tracking
var enrichedTags = union(tags, {
  LastDeployedDate: !empty(deployedDate) ? deployedDate : 'Unknown'
  LastDeployedBy: !empty(deployedBy) ? deployedBy : 'Unknown'
})

var subnets = [
  {
    name: 'AzureBastionSubnet'
    addressPrefix: cidrSubnet(mgmtVnetAddressSpace, 24, 0) // 10.90.0.0/24
    nsg: false
  }
  {
    name: 'DevOpsRunners'
    addressPrefix: cidrSubnet(mgmtVnetAddressSpace, 24, 1) // 10.90.1.0/24
    nsg: true
  }
  {
    name: 'Public'
    addressPrefix: cidrSubnet(mgmtVnetAddressSpace, 24, 2) // 10.90.2.0/24
    nsg: false
  }
  {
    name: 'GatewaySubnet'
    addressPrefix: cidrSubnet(mgmtVnetAddressSpace, 24, 3) // 10.90.3.0/24
    nsg: false
  }
]

// ===================== //
// Log Analytics         //
// ===================== //

// Reference existing Log Analytics Workspace instead of creating new one
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: lawName
}

// ===================== //
// Management Network    //
// ===================== //

module mgmtVnet './modules/virtualnetwork/main.bicep' = {
  name: 'deploy-mgmt-vnet-${uniqueString(resourceGroup().id)}'
  scope: resourceGroup(networkingResourceGroupName)
  params: {
    name: mgmtVnetName
    location: location
    tags: enrichedTags
    addressPrefixes: [mgmtVnetAddressSpace]
    subnets: subnets
    logAnalyticsWorkspaceId: logAnalytics.id
  }
}

// ===================== //
// Self-Hosted Runner VM //
// ===================== //

// Reference existing Key Vault to retrieve VM admin password
resource existingKeyVault 'Microsoft.KeyVault/vaults@2024-11-01' existing = if (deploySelfHostedRunner) {
  name: keyVaultName
  scope: resourceGroup()
}

module runnerVM './modules/vm/main.bicep' = if (deploySelfHostedRunner) {
  name: 'deploy-runner-vm-${uniqueString(resourceGroup().id)}'
  params: {
    name: vmName
    location: location
    tags: enrichedTags
    adminUsername: vmAdminUsername
    adminPassword: existingKeyVault!.getSecret('vmAdminPassword')
    osType: 'Linux'
    vmSize: 'Standard_B2s'
    osDiskSizeGB: 64
    subnetId: mgmtVnet.outputs.subnetIds[1] // DevOpsRunners subnet
    enablePublicIP: false
    customData: loadTextContent('../scripts/install-github-runner.sh')
  }
}

// ===================== //
// Application Gateway   //
// ===================== //

module appGateway './modules/appgateway/main.bicep' = if (deployAppGateway) {
  name: 'deploy-appgw-${uniqueString(resourceGroup().id)}'
  scope: resourceGroup(networkingResourceGroupName)
  params: {
    name: 'appgw-${workloadName}-prod'
    location: location
    tags: enrichedTags
    subnetId: mgmtVnet.outputs.subnetIds[2] // Public subnet
    sku: 'WAF_v2'
    capacity: 2
    logAnalyticsWorkspaceId: logAnalytics.id
  }
}

// ===================== //
// Private DNS Zones     //
// ===================== //

var privateDnsZones = [
  'privatelink.azurewebsites.net'
  'privatelink.vaultcore.azure.net'
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.file.${environment().suffixes.storage}'
]

module privateDns './modules/privatedns/main.bicep' = [for zone in privateDnsZones: {
  name: 'deploy-dns-${replace(zone, '.', '-')}'
  scope: resourceGroup(networkingResourceGroupName)
  params: {
    zoneName: zone
    tags: enrichedTags
    vnetId: mgmtVnet.outputs.resourceId
  }
}]

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the Log Analytics Workspace.')
output logAnalyticsWorkspaceId string = logAnalytics.id

@description('The name of the Log Analytics Workspace.')
output logAnalyticsWorkspaceName string = logAnalytics.name

@description('The resource ID of the management VNet.')
output mgmtVnetId string = mgmtVnet.outputs.resourceId

@description('The name of the management VNet.')
output mgmtVnetName string = mgmtVnet.outputs.name

@description('The resource ID of the runner VM.')
output runnerVmId string = deploySelfHostedRunner ? runnerVM!.outputs.resourceId : ''

@description('The private IP of the runner VM.')
output runnerVmPrivateIp string = deploySelfHostedRunner ? runnerVM!.outputs.privateIpAddress : ''

@description('The resource ID of the Application Gateway.')
output appGatewayId string = deployAppGateway ? appGateway!.outputs.resourceId : ''
