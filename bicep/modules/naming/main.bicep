metadata name = 'Naming Helper Module'
metadata description = 'Generates standardized resource names following Azure Cloud Adoption Framework (CAF) naming conventions'
metadata owner = 'BenTheBuilder'
metadata version = '1.0.0'
metadata references = [
  'https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming'
  'https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations'
]

// ============ //
// Parameters   //
// ============ //

@description('Required. Primary Azure region abbreviation for naming.')
@allowed([
  'eus'   // eastus
  'eus2'  // eastus2
  'wus2'  // westus2
  'cus'   // centralus
])
param regionAbbreviation string

@description('Required. Environment identifier.')
@allowed([
  'dev'
  'qa'
  'prod'
])
param environment string

@description('Required. Workload or application name.')
@minLength(2)
@maxLength(10)
param workloadName string

@description('Optional. Additional suffix for resource uniqueness (e.g., uniqueString).')
@maxLength(13)
param uniqueSuffix string = ''

@description('Optional. Organization or business unit abbreviation.')
@maxLength(5)
param orgPrefix string = ''

@description('Optional. Instance number for resources that support multiple instances.')
@minValue(1)
@maxValue(999)
param instance int = 1

// ============== //
// Variables      //
// ============== //

// Instance number formatted with leading zeros (001, 002, etc.)
var instanceFormatted = padLeft(string(instance), 3, '0')

// Base naming components
var basePrefix = !empty(orgPrefix) ? '${orgPrefix}-' : ''
var baseName = !empty(uniqueSuffix) ? '${workloadName}-${uniqueSuffix}' : workloadName

// Region mapping for full names (used in resource group names)
var regionMapping = {
  eus: 'eastus'
  eus2: 'eastus2'
  wus2: 'westus2'
  cus: 'centralus'
}

// ==================== //
// Resource Names       //
// ==================== //

// Resource Group Names (include full region name per CAF)
var resourceGroupGeneral = '${basePrefix}rg-${regionMapping[regionAbbreviation]}-${environment}-${workloadName}'
var resourceGroupNetworking = '${basePrefix}rg-${regionMapping[regionAbbreviation]}-${environment}-${workloadName}-networking'
var resourceGroupMgmt = '${basePrefix}rg-${regionMapping[regionAbbreviation]}-prod-mgmt-common'
var resourceGroupMgmtNetworking = '${basePrefix}rg-${regionMapping[regionAbbreviation]}-prod-mgmt-networking'

// Virtual Network Names
var virtualNetwork = '${basePrefix}vnet-${regionAbbreviation}-${environment}-${workloadName}'
var virtualNetworkMgmt = '${basePrefix}vnet-${regionAbbreviation}-prod-mgmt'

// Subnet Names (no prefix per CAF)
var subnetPrivateEndpoints = 'PrivateEndpoints'
var subnetAppServices = 'AppServices'
var subnetBastion = 'AzureBastionSubnet'
var subnetDevOpsRunners = 'DevOpsRunners'
var subnetPublic = 'Public'
var subnetGateway = 'GatewaySubnet'

// Network Security Group Names
var networkSecurityGroup = '${basePrefix}nsg-${regionAbbreviation}-${environment}-${workloadName}-${instanceFormatted}'

// Key Vault Name (24 char limit, lowercase alphanumeric and hyphens only)
var keyVault = take('${basePrefix}kv-${regionAbbreviation}-${environment}-${baseName}', 24)

// Storage Account Name (24 char limit, lowercase alphanumeric only, no hyphens)
var storageAccount = take(toLower(replace('${basePrefix}st${regionAbbreviation}${environment}${workloadName}${uniqueSuffix}', '-', '')), 24)

// App Service Plan Name
var appServicePlan = '${basePrefix}asp-${regionAbbreviation}-${environment}-${workloadName}'

// Web App / Function App Names
var webApp = '${basePrefix}app-${regionAbbreviation}-${environment}-${baseName}'
var functionApp = '${basePrefix}func-${regionAbbreviation}-${environment}-${baseName}'

// Log Analytics Workspace Name
var logAnalyticsWorkspace = '${basePrefix}law-${regionAbbreviation}-${environment}-${workloadName}'

// Application Insights Name
var applicationInsights = '${basePrefix}appi-${regionAbbreviation}-${environment}-${workloadName}'

// Virtual Machine Names (15 char limit for Windows, 64 for Linux)
var virtualMachine = '${basePrefix}vm-${regionAbbreviation}-${environment}-${workloadName}-${instanceFormatted}'
var virtualMachineWindows = take('${basePrefix}vm${regionAbbreviation}${environment}${workloadName}${instanceFormatted}', 15)

// Network Interface Name
var networkInterface = '${basePrefix}nic-${regionAbbreviation}-${environment}-${workloadName}-${instanceFormatted}'

// Public IP Address Name
var publicIpAddress = '${basePrefix}pip-${regionAbbreviation}-${environment}-${workloadName}-${instanceFormatted}'

// Load Balancer Name
var loadBalancer = '${basePrefix}lb-${regionAbbreviation}-${environment}-${workloadName}'

// Application Gateway Name
var applicationGateway = '${basePrefix}agw-${regionAbbreviation}-${environment}-${workloadName}'

// Private Endpoint Names (resource-specific)
var privateEndpointKeyVault = '${basePrefix}pe-${regionAbbreviation}-${environment}-${workloadName}-kv'
var privateEndpointStorage = '${basePrefix}pe-${regionAbbreviation}-${environment}-${workloadName}-st'
var privateEndpointSql = '${basePrefix}pe-${regionAbbreviation}-${environment}-${workloadName}-sql'

// Private DNS Zone Names (Azure-defined, fixed format)
var privateDnsZoneKeyVault = 'privatelink.vaultcore.azure.net'
var privateDnsZoneStorageBlob = 'privatelink.blob.${az.environment().suffixes.storage}'
var privateDnsZoneStorageFile = 'privatelink.file.${az.environment().suffixes.storage}'
var privateDnsZoneSql = 'privatelink${az.environment().suffixes.sqlServerHostname}'
var privateDnsZoneWebApp = 'privatelink.azurewebsites.net'

// Azure SQL Database Names
var sqlServer = '${basePrefix}sql-${regionAbbreviation}-${environment}-${baseName}'
var sqlDatabase = '${basePrefix}sqldb-${regionAbbreviation}-${environment}-${workloadName}'

// Azure Container Registry Name (50 char limit, alphanumeric only)
var containerRegistry = take(toLower(replace('${basePrefix}acr${regionAbbreviation}${environment}${workloadName}${uniqueSuffix}', '-', '')), 50)

// Azure Kubernetes Service Name
var kubernetesCluster = '${basePrefix}aks-${regionAbbreviation}-${environment}-${workloadName}'

// Azure Bastion Name
var bastion = '${basePrefix}bas-${regionAbbreviation}-${environment}-${workloadName}'

// User Assigned Managed Identity Name
var managedIdentity = '${basePrefix}id-${regionAbbreviation}-${environment}-${workloadName}-${instanceFormatted}'

// Azure Cosmos DB Account Name (44 char limit, lowercase letters, numbers, and hyphens)
var cosmosDbAccount = take('${basePrefix}cosmos-${regionAbbreviation}-${environment}-${baseName}', 44)

// Azure Service Bus Namespace Name (50 char limit)
var serviceBusNamespace = take('${basePrefix}sb-${regionAbbreviation}-${environment}-${baseName}', 50)

// Azure Event Hub Namespace Name (50 char limit)
var eventHubNamespace = take('${basePrefix}evhns-${regionAbbreviation}-${environment}-${baseName}', 50)

// Azure API Management Name (50 char limit)
var apiManagement = take('${basePrefix}apim-${regionAbbreviation}-${environment}-${baseName}', 50)

// Azure Cache for Redis Name (63 char limit)
var redisCache = take('${basePrefix}redis-${regionAbbreviation}-${environment}-${baseName}', 63)

// Azure Front Door Name
var frontDoor = '${basePrefix}fd-${regionAbbreviation}-${environment}-${workloadName}'

// Azure CDN Profile Name
var cdnProfile = '${basePrefix}cdnp-${regionAbbreviation}-${environment}-${workloadName}'

// Azure Recovery Services Vault Name (50 char limit)
var recoveryServicesVault = take('${basePrefix}rsv-${regionAbbreviation}-${environment}-${workloadName}', 50)

// Azure Automation Account Name (50 char limit)
var automationAccount = take('${basePrefix}aa-${regionAbbreviation}-${environment}-${workloadName}', 50)

// ============ //
// Outputs      //
// ============ //

// Configuration Outputs
@description('The region abbreviation used for naming.')
output regionAbbreviation string = regionAbbreviation

@description('The full region name.')
output regionName string = regionMapping[regionAbbreviation]

@description('The environment identifier.')
output environment string = environment

@description('The workload name.')
output workloadName string = workloadName

@description('The unique suffix (if provided).')
output uniqueSuffix string = uniqueSuffix

@description('The formatted instance number.')
output instance string = instanceFormatted

// Resource Group Names
@description('General resource group name.')
output resourceGroupGeneral string = resourceGroupGeneral

@description('Networking resource group name.')
output resourceGroupNetworking string = resourceGroupNetworking

@description('Management resource group name.')
output resourceGroupMgmt string = resourceGroupMgmt

@description('Management networking resource group name.')
output resourceGroupMgmtNetworking string = resourceGroupMgmtNetworking

// Network Resource Names
@description('Environment virtual network name.')
output virtualNetwork string = virtualNetwork

@description('Management virtual network name.')
output virtualNetworkMgmt string = virtualNetworkMgmt

@description('Network security group name.')
output networkSecurityGroup string = networkSecurityGroup

@description('Network interface name.')
output networkInterface string = networkInterface

@description('Public IP address name.')
output publicIpAddress string = publicIpAddress

// Subnet Names
@description('Private endpoints subnet name.')
output subnetPrivateEndpoints string = subnetPrivateEndpoints

@description('App Services subnet name.')
output subnetAppServices string = subnetAppServices

@description('Azure Bastion subnet name.')
output subnetBastion string = subnetBastion

@description('DevOps runners subnet name.')
output subnetDevOpsRunners string = subnetDevOpsRunners

@description('Public subnet name.')
output subnetPublic string = subnetPublic

@description('Gateway subnet name.')
output subnetGateway string = subnetGateway

// Identity and Security Names
@description('Key Vault name.')
output keyVault string = keyVault

@description('Managed identity name.')
output managedIdentity string = managedIdentity

// Storage Names
@description('Storage account name.')
output storageAccount string = storageAccount

// Compute Names
@description('App Service Plan name.')
output appServicePlan string = appServicePlan

@description('Web App name.')
output webApp string = webApp

@description('Function App name.')
output functionApp string = functionApp

@description('Virtual machine name (Linux).')
output virtualMachine string = virtualMachine

@description('Virtual machine name (Windows, 15 char limit).')
output virtualMachineWindows string = virtualMachineWindows

// Monitoring Names
@description('Log Analytics Workspace name.')
output logAnalyticsWorkspace string = logAnalyticsWorkspace

@description('Application Insights name.')
output applicationInsights string = applicationInsights

// Gateway and Load Balancer Names
@description('Application Gateway name.')
output applicationGateway string = applicationGateway

@description('Load Balancer name.')
output loadBalancer string = loadBalancer

@description('Azure Bastion name.')
output bastion string = bastion

// Private Endpoint Names
@description('Key Vault private endpoint name.')
output privateEndpointKeyVault string = privateEndpointKeyVault

@description('Storage private endpoint name.')
output privateEndpointStorage string = privateEndpointStorage

@description('SQL private endpoint name.')
output privateEndpointSql string = privateEndpointSql

// Private DNS Zone Names
@description('Key Vault private DNS zone name.')
output privateDnsZoneKeyVault string = privateDnsZoneKeyVault

@description('Storage Blob private DNS zone name.')
output privateDnsZoneStorageBlob string = privateDnsZoneStorageBlob

@description('Storage File private DNS zone name.')
output privateDnsZoneStorageFile string = privateDnsZoneStorageFile

@description('SQL private DNS zone name.')
output privateDnsZoneSql string = privateDnsZoneSql

@description('Web App private DNS zone name.')
output privateDnsZoneWebApp string = privateDnsZoneWebApp

// Database Names
@description('SQL Server name.')
output sqlServer string = sqlServer

@description('SQL Database name.')
output sqlDatabase string = sqlDatabase

@description('Cosmos DB account name.')
output cosmosDbAccount string = cosmosDbAccount

// Container and Kubernetes Names
@description('Container Registry name.')
output containerRegistry string = containerRegistry

@description('Azure Kubernetes Service cluster name.')
output kubernetesCluster string = kubernetesCluster

// Messaging and Integration Names
@description('Service Bus namespace name.')
output serviceBusNamespace string = serviceBusNamespace

@description('Event Hub namespace name.')
output eventHubNamespace string = eventHubNamespace

@description('API Management service name.')
output apiManagement string = apiManagement

// Cache Names
@description('Azure Cache for Redis name.')
output redisCache string = redisCache

// CDN and Front Door Names
@description('Azure Front Door name.')
output frontDoor string = frontDoor

@description('CDN Profile name.')
output cdnProfile string = cdnProfile

// Backup and Automation Names
@description('Recovery Services Vault name.')
output recoveryServicesVault string = recoveryServicesVault

@description('Automation Account name.')
output automationAccount string = automationAccount
