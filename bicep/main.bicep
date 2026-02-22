metadata name = 'WebApp Demo - Main Orchestrator'
metadata description = 'Main orchestration template for WebApp CI/CD Demo'
metadata owner = 'BenTheBuilder'
metadata version = '1.0.0'

targetScope = 'subscription'

// ============ //
// Parameters   //
// ============ //

@description('Required. Primary Azure region for deployment.')
@allowed([
  'eastus'
  'eastus2'
  'westus2'
  'centralus'
])
param primaryRegion string

@description('Required. Environment identifier.')
@allowed([
  'dev'
  'qa'
  'prod'
])
param environment string

@description('Required. Workload name used for resource naming.')
@minLength(2)
@maxLength(10)
param workloadName string = 'webapp'

@description('Required. Date and time of deployment (ISO 8601 format).')
param deployedDate string = utcNow('yyyy-MM-ddTHH:mm:ssZ')

@description('Required. GitHub username of person deploying.')
param deployedBy string

@description('Optional. Deploy common management resources (production only, first time).')
param deployCommonMgmt bool = false

@description('Optional. Enable Application Gateway deployment.')
param deployAppGateway bool = false

@description('Optional. Enable VM deployment for self-hosted runner.')
param deploySelfHostedRunner bool = false

@description('Optional. Log Analytics Workspace Resource ID. Required if not deploying common management resources.')
param logAnalyticsWorkspaceId string = ''

@description('Optional. Admin username for VM. Password will be retrieved from Key Vault.')
@secure()
param vmAdminUsername string = ''

@description('Optional. Key Vault name where VM admin password is stored. Required if deploying self-hosted runner.')
param keyVaultName string = ''

@description('Deployment name for the environment resources. If not provided, a unique name will be generated.')
param deploymentName string = ''!

// ============ //
// Variables    //
// ============ //

var commonTags = {
  Owner: 'BenTheBuilder'
  Environment: environment
  DeployedDate: deployedDate
  DeployedBy: deployedBy
  DeploymentName: deploymentName
  Platform: 'DemoApp'
  Notes: 'This is a DemoApp PoC - short lived!'
}

// Resource Group Names
var rgCommonName = 'rg-${primaryRegion}-prod-mgmt-common'
var rgNetworkingCommonName = 'rg-${primaryRegion}-prod-mgmt-networking'
var rgEnvironmentName = 'rg-${primaryRegion}-${environment}-${workloadName}'
var rgEnvironmentNetworkingName = 'rg-${primaryRegion}-${environment}-${workloadName}-networking'

// Network Configuration
var mgmtVnetAddressSpace = '10.90.0.0/22'
var envVnetAddressSpace = environment == 'dev' ? '10.90.4.0/24' : environment == 'qa' ? '10.90.5.0/24' : '10.90.6.0/24'

// ==================== //
// Resource Groups      //
// ==================== //

// Common Management Resource Groups (Production Only)
resource rgCommon 'Microsoft.Resources/resourceGroups@2021-04-01' = if (deployCommonMgmt && environment == 'prod') {
  name: rgCommonName
  location: primaryRegion
  tags: commonTags
}

resource rgNetworkingCommon 'Microsoft.Resources/resourceGroups@2021-04-01' = if (deployCommonMgmt && environment == 'prod') {
  name: rgNetworkingCommonName
  location: primaryRegion
  tags: commonTags
}

// Environment Resource Groups
resource rgEnvironment 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgEnvironmentName
  location: primaryRegion
  tags: commonTags
}

resource rgEnvironmentNetworking 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgEnvironmentNetworkingName
  location: primaryRegion
  tags: commonTags
}

// ==================== //
// Common Management    //
// ==================== //

module commonMgmt './common-mgmt.bicep' = if (deployCommonMgmt && environment == 'prod') {
  name: 'deploy-common-mgmt-${deployedDate}'
  scope: rgCommon
  params: {
    location: primaryRegion
    workloadName: workloadName
    deployedDate: deployedDate
    deployedBy: deployedBy
    tags: commonTags
    mgmtVnetAddressSpace: mgmtVnetAddressSpace
    deployAppGateway: deployAppGateway
    deploySelfHostedRunner: deploySelfHostedRunner
    vmAdminUsername: vmAdminUsername
    keyVaultName: keyVaultName
    networkingResourceGroupName: rgNetworkingCommonName
  }
  dependsOn: [
    rgNetworkingCommon
  ]
}

// ======================== //
// Environment Resources    //
// ======================== //

module environmentResources './environment.bicep' = {
  name: 'deploy-env-${environment}-${deployedDate}'
  scope: rgEnvironment
  params: {
    location: primaryRegion
    environment: environment
    workloadName: workloadName
    deployedDate: deployedDate
    deployedBy: deployedBy
    tags: commonTags
    envVnetAddressSpace: envVnetAddressSpace
    logAnalyticsWorkspaceId: deployCommonMgmt && environment == 'prod' ? commonMgmt!.outputs.logAnalyticsWorkspaceId : logAnalyticsWorkspaceId
    logAnalyticsWorkspaceName: deployCommonMgmt && environment == 'prod' ? commonMgmt!.outputs.logAnalyticsWorkspaceName : split(logAnalyticsWorkspaceId, '/')[8]
    networkingResourceGroupName: rgEnvironmentNetworkingName
    mgmtVnetId: deployCommonMgmt && environment == 'prod' ? commonMgmt!.outputs.mgmtVnetId : ''
  }
  dependsOn: [
    rgEnvironmentNetworking
  ]
}

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the Log Analytics Workspace.')
output logAnalyticsWorkspaceId string = deployCommonMgmt && environment == 'prod' ? commonMgmt!.outputs.logAnalyticsWorkspaceId : logAnalyticsWorkspaceId

@description('The resource ID of the management VNet.')
output mgmtVnetId string = deployCommonMgmt && environment == 'prod' ? commonMgmt!.outputs.mgmtVnetId : ''

@description('The resource ID of the environment VNet.')
output envVnetId string = environmentResources.outputs.envVnetId

@description('The name of the Web App.')
output webAppName string = environmentResources.outputs.webAppName

@description('The default hostname of the Web App.')
output webAppDefaultHostname string = environmentResources.outputs.webAppDefaultHostname

@description('The name of the Key Vault.')
output keyVaultName string = environmentResources.outputs.keyVaultName

@description('The resource ID of the Key Vault.')
output keyVaultId string = environmentResources.outputs.keyVaultId

@description('The principal ID of the Web App managed identity.')
output webAppPrincipalId string = environmentResources.outputs.webAppPrincipalId
