using '../bicep/main.bicep'

param primaryRegion = 'centralus'
param environment = 'prod'
param workloadName = 'webapp'
param deployedBy = 'github-actions'
param deployCommonMgmt = true  // First time only, then set to false
param deployAppGateway = true
param deploySelfHostedRunner = true
param logAnalyticsWorkspaceId = ''  // Will be created during initial deployment, then reference existing
param vmAdminUsername = 'adminuser'
param keyVaultName = 'kv-mgmt-prod-secrets'
