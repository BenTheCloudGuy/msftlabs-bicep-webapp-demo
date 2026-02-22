metadata name = 'Virtual Machine Module'
metadata description = 'Deploys Azure Virtual Machine with SystemAssigned Managed Identity for passwordless authentication'
metadata owner = 'BenTheBuilder'

targetScope = 'resourceGroup'

// ============================================ //
// Managed Identity & RBAC Best Practices       //
// ============================================ //
// This module deploys a VM with SystemAssigned Managed Identity.
// The managed identity enables passwordless authentication to Azure resources.
//
// Common use cases for VM Managed Identity:
// - Access Azure Key Vault to retrieve secrets/certificates
// - Write logs/metrics to Log Analytics or Application Insights
// - Access Storage Accounts without connection strings
// - Authenticate to Azure Container Registry
// - Call Azure APIs (ARM, Graph, etc.)
//
// The VM's managed identity should be granted:
// - Log Analytics Contributor (if sending custom logs)
// - Monitoring Metrics Publisher (if sending custom metrics)
// - Key Vault Secrets User (if reading secrets)
// - Storage Blob Data Contributor/Reader (if accessing storage)
//
// Use the loganalytics/rbac.bicep, keyvault/rbac.bicep or common/rbac.bicep modules

// ============ //
// Parameters   //
// ============ //

@description('Required. Name of the Virtual Machine.')
param name string

@description('Optional. Location for the VM.')
param location string = resourceGroup().location

@description('Optional. Tags for the VM.')
param tags object = {}

@description('Required. Admin username.')
@secure()
param adminUsername string

@description('Required. Admin password or SSH key.')
@secure()
param adminPassword string

@description('Required. OS type.')
@allowed([
  'Linux'
  'Windows'
])
param osType string

@description('Optional. VM size.')
param vmSize string = 'Standard_B2s'

@description('Optional. OS disk size in GB.')
param osDiskSizeGB int = 64

@description('Required. Subnet ID for the NIC.')
param subnetId string

@description('Optional. Enable public IP.')
param enablePublicIP bool = false

@description('Optional. Custom data (cloud-init for Linux).')
param customData string = ''

// ==================== //
// Variables            //
// ==================== //

var nicName = '${name}-nic'
var publicIpName = '${name}-pip'
var linuxImage = {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-jammy'
  sku: '22_04-lts-gen2'
  version: 'latest'
}

// ==================== //
// Public IP            //
// ==================== //

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (enablePublicIP) {
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

// ==================== //
// Network Interface    //
// ==================== //

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: enablePublicIP ? {
            id: publicIp.id
          } : null
        }
      }
    ]
  }
}

// ==================== //
// Virtual Machine      //
// ==================== //

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: name
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: !empty(customData) ? base64(customData) : null
      linuxConfiguration: osType == 'Linux' ? {
        disablePasswordAuthentication: false
        provisionVMAgent: true
        patchSettings: {
          patchMode: 'ImageDefault'
          assessmentMode: 'ImageDefault'
        }
      } : null
    }
    storageProfile: {
      imageReference: osType == 'Linux' ? linuxImage : null
      osDisk: {
        name: '${name}-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        diskSizeGB: osDiskSizeGB
        deleteOption: 'Delete'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

// Resource lock
resource lock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: '${name}-lock'
  scope: vm
  properties: {
    level: 'CanNotDelete'
    notes: 'Prevents accidental deletion of Virtual Machine'
  }
}

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the Virtual Machine.')
output resourceId string = vm.id

@description('The name of the Virtual Machine.')
output name string = vm.name

@description('The principal ID of the system-assigned managed identity.')
output principalId string = vm.identity.principalId

@description('The private IP address of the VM.')
output privateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress

@description('The public IP address of the VM (if enabled).')
output publicIpAddress string = enablePublicIP ? publicIp!.properties.ipAddress : ''
