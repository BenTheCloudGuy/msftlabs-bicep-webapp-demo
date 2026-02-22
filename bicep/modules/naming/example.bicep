metadata name = 'Naming Module Integration Example'
metadata description = 'Shows how to integrate the naming module and use generated names'
metadata owner = 'BenTheBuilder'

targetScope = 'resourceGroup'

// ============ //
// Parameters   //
// ============ //

@description('Required. Azure region abbreviation.')
@allowed([
  'eus'
  'eus2'
  'wus2'
  'cus'
])
param regionAbbreviation string = 'cus'

@description('Required. Environment identifier.')
@allowed([
  'dev'
  'qa'
  'prod'
])
param environment string = 'dev'

@description('Required. Workload name used for resource naming.')
@minLength(2)
@maxLength(10)
param workloadName string = 'webapp'

@description('Optional. Organization prefix for naming.')
param orgPrefix string = ''

// ============ //
// Variables    //
// ============ //

// Generate unique suffix for globally unique resources
var uniqueSuffix = uniqueString(resourceGroup().id)

// ==================== //
// Naming Module        //
// ==================== //

// Call the naming module to generate all resource names
module naming './main.bicep' = {
  name: 'naming-standards-${uniqueString(deployment().name)}'
  params: {
    regionAbbreviation: regionAbbreviation
    environment: environment
    workloadName: workloadName
    uniqueSuffix: uniqueSuffix
    orgPrefix: orgPrefix
    instance: 1
  }
}

// ==================== //
// Usage Notes          //
// ==================== //

/*
  How to use the naming module in your Bicep templates:
  
  1. For resource deployments, use the naming outputs directly:
  
     resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
       name: naming.outputs.keyVault
       // ... rest of configuration
     }
  
  2. For passing to child modules:
  
     module storage './modules/storage/main.bicep' = {
       scope: resourceGroup()
       params: {
         name: naming.outputs.storageAccount
         location: location
       }
     }
  
  3. For resource group names (subscription-scoped deployments):
     Due to Bicep deployment-time limitations, resource group names 
     should be calculated as variables, not from module outputs:
     
     var rgName = '${orgPrefix}-rg-${location}-${environment}-${workloadName}'
     
     Or use the naming module outputs in outputs/logs only.
  
  4. For multi-instance resources:
     Call the naming module multiple times with different instance numbers,
     or use string interpolation with the base pattern.
*/

// ============ //
// Outputs      //
// ============ //

@description('All generated resource names for reference.')
output resourceNames object = {
  resourceGroups: {
    general: naming.outputs.resourceGroupGeneral
    networking: naming.outputs.resourceGroupNetworking
    mgmt: naming.outputs.resourceGroupMgmt
    mgmtNetworking: naming.outputs.resourceGroupMgmtNetworking
  }
  networking: {
    virtualNetwork: naming.outputs.virtualNetwork
    virtualNetworkMgmt: naming.outputs.virtualNetworkMgmt
    nsg: naming.outputs.networkSecurityGroup
    nic: naming.outputs.networkInterface
    pip: naming.outputs.publicIpAddress
    appGateway: naming.outputs.applicationGateway
    loadBalancer: naming.outputs.loadBalancer
    bastion: naming.outputs.bastion
  }
  subnets: {
    privateEndpoints: naming.outputs.subnetPrivateEndpoints
    appServices: naming.outputs.subnetAppServices
    bastion: naming.outputs.subnetBastion
    devOpsRunners: naming.outputs.subnetDevOpsRunners
    public: naming.outputs.subnetPublic
    gateway: naming.outputs.subnetGateway
  }
  compute: {
    appServicePlan: naming.outputs.appServicePlan
    webApp: naming.outputs.webApp
    functionApp: naming.outputs.functionApp
    vm: naming.outputs.virtualMachine
    vmWindows: naming.outputs.virtualMachineWindows
    aks: naming.outputs.kubernetesCluster
    acr: naming.outputs.containerRegistry
  }
  storage: {
    storageAccount: naming.outputs.storageAccount
  }
  security: {
    keyVault: naming.outputs.keyVault
    managedIdentity: naming.outputs.managedIdentity
  }
  monitoring: {
    logAnalytics: naming.outputs.logAnalyticsWorkspace
    applicationInsights: naming.outputs.applicationInsights
  }
  database: {
    sqlServer: naming.outputs.sqlServer
    sqlDatabase: naming.outputs.sqlDatabase
    cosmosDb: naming.outputs.cosmosDbAccount
    redis: naming.outputs.redisCache
  }
  messaging: {
    serviceBus: naming.outputs.serviceBusNamespace
    eventHub: naming.outputs.eventHubNamespace
    apiManagement: naming.outputs.apiManagement
  }
  privateEndpoints: {
    keyVault: naming.outputs.privateEndpointKeyVault
    storage: naming.outputs.privateEndpointStorage
    sql: naming.outputs.privateEndpointSql
  }
  privateDnsZones: {
    keyVault: naming.outputs.privateDnsZoneKeyVault
    storageBlob: naming.outputs.privateDnsZoneStorageBlob
    storageFile: naming.outputs.privateDnsZoneStorageFile
    sql: naming.outputs.privateDnsZoneSql
    webApp: naming.outputs.privateDnsZoneWebApp
  }
  cdn: {
    frontDoor: naming.outputs.frontDoor
    cdnProfile: naming.outputs.cdnProfile
  }
  management: {
    recoveryServicesVault: naming.outputs.recoveryServicesVault
    automationAccount: naming.outputs.automationAccount
  }
}

@description('Summary of naming configuration.')
output namingConfiguration object = {
  regionAbbreviation: regionAbbreviation
  regionName: naming.outputs.regionName
  environment: environment
  workloadName: workloadName
  uniqueSuffix: uniqueSuffix
  orgPrefix: orgPrefix
  instance: '001'
}

@description('Example usage guidance.')
output usageExamples object = {
  keyVault: 'Use naming.outputs.keyVault for Key Vault resource name'
  storageAccount: 'Use naming.outputs.storageAccount for Storage Account resource name'
  webApp: 'Use naming.outputs.webApp for Web App resource name'
  virtualMachine: 'Use naming.outputs.virtualMachine for Virtual Machine resource name'
  passToChildModule: 'Pass naming outputs as parameters to child modules for resource deployment'
}

