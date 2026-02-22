using '../bicep/main.bicep'

param primaryRegion = 'centralus'
param environment = 'qa'
param workloadName = 'webapp'
param deployedBy = 'github-actions'
param deployCommonMgmt = false
param deployAppGateway = false
param deploySelfHostedRunner = false
param logAnalyticsWorkspaceId = '/subscriptions/934600ac-0f19-44b8-b439-b4c5f02d8a7d/resourceGroups/rg-centralus-prod-mgmt-common/providers/Microsoft.OperationalInsights/workspaces/core-law'
param vmAdminUsername = 'adminuserqa'
param keyVaultName = 'kv-mgmt-prod-secrets'
param deploymentName = 'msftlabs-webapp-demo-qa-deployment'
