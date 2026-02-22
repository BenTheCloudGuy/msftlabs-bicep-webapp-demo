using '../bicep/main.bicep'

param primaryRegion = 'centralus'
param environment = 'dev'
param workloadName = 'webapp'
param deployedBy = 'github-actions'
param deployCommonMgmt = false
param deployAppGateway = false
param deploySelfHostedRunner = false
param logAnalyticsWorkspaceId = '/subscriptions/934600ac-0f19-44b8-b439-b4c5f02d8a7d/resourceGroups/rg-centralus-prod-mgmt-common/providers/Microsoft.OperationalInsights/workspaces/core-law'
param vmAdminUsername = 'adminuser'
param keyVaultName = 'kv-mgmt-prod-secrets'
