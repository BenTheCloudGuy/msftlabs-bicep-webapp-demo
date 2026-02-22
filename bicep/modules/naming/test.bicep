metadata name = 'Naming Module Tests'
metadata description = 'Validates naming module outputs meet Azure naming requirements'

targetScope = 'resourceGroup'

// ==================== //
// Test Configuration   //
// ==================== //

param testEnvironment string = 'dev'

// ==================== //
// Naming Module Call   //
// ==================== //

module naming './main.bicep' = {
  name: 'test-naming-${uniqueString(deployment().name)}'
  params: {
    regionAbbreviation: 'cus'
    environment: testEnvironment
    workloadName: 'webapp'
    uniqueSuffix: 'test1234'
    orgPrefix: 'test'
    instance: 1
  }
}

// ==================== //
// Validation Tests     //
// ==================== //

// Test 1: Storage Account Name - Max 24 chars, lowercase alphanumeric only
var storageAccountIsValid = length(naming.outputs.storageAccount) <= 24 && toLower(naming.outputs.storageAccount) == naming.outputs.storageAccount && !contains(naming.outputs.storageAccount, '-')

// Test 2: Key Vault Name - Max 24 chars, alphanumeric and hyphens
var keyVaultIsValid = length(naming.outputs.keyVault) <= 24 && length(naming.outputs.keyVault) >= 3

// Test 3: Windows VM Name - Max 15 chars
var vmWindowsIsValid = length(naming.outputs.virtualMachineWindows) <= 15

// Test 4: Linux VM Name - Max 64 chars
var vmLinuxIsValid = length(naming.outputs.virtualMachine) <= 64

// Test 5: Container Registry - Max 50 chars, alphanumeric only
var acrIsValid = length(naming.outputs.containerRegistry) <= 50 && !contains(naming.outputs.containerRegistry, '-')

// Test 6: Resource Group Names include full region name
var rgHasFullRegion = contains(naming.outputs.resourceGroupGeneral, 'centralus')

// Test 7: All outputs are non-empty
var allOutputsNonEmpty = !empty(naming.outputs.keyVault) && !empty(naming.outputs.storageAccount) && !empty(naming.outputs.webApp) && !empty(naming.outputs.virtualMachine)

// ==================== //
// Test Results         //
// ==================== //

output testResults object = {
  allTests: {
    storageAccountNameValid: storageAccountIsValid
    keyVaultNameValid: keyVaultIsValid
    windowsVmNameValid: vmWindowsIsValid
    linuxVmNameValid: vmLinuxIsValid
    containerRegistryNameValid: acrIsValid
    resourceGroupHasFullRegion: rgHasFullRegion
    allOutputsNonEmpty: allOutputsNonEmpty
  }
  testStatus: storageAccountIsValid && keyVaultIsValid && vmWindowsIsValid && vmLinuxIsValid && acrIsValid && rgHasFullRegion && allOutputsNonEmpty ? 'PASSED' : 'FAILED'
}

output sampleNames object = {
  storageAccount: '${naming.outputs.storageAccount} (len: ${length(naming.outputs.storageAccount)})'
  keyVault: '${naming.outputs.keyVault} (len: ${length(naming.outputs.keyVault)})'
  webApp: naming.outputs.webApp
  virtualMachine: naming.outputs.virtualMachine
  virtualMachineWindows: '${naming.outputs.virtualMachineWindows} (len: ${length(naming.outputs.virtualMachineWindows)})'
  containerRegistry: '${naming.outputs.containerRegistry} (len: ${length(naming.outputs.containerRegistry)})'
  resourceGroupGeneral: naming.outputs.resourceGroupGeneral
  resourceGroupNetworking: naming.outputs.resourceGroupNetworking
}

output validationSummary string = storageAccountIsValid && keyVaultIsValid && vmWindowsIsValid && vmLinuxIsValid && acrIsValid && rgHasFullRegion && allOutputsNonEmpty ? 'All naming validation tests PASSED' : 'Some naming validation tests FAILED - review testResults output'
