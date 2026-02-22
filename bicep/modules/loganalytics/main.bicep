metadata name = 'Log Analytics Workspace Module'
metadata description = 'Deploys Azure Log Analytics Workspace with resource-level RBAC permissions'
metadata owner = 'BenTheBuilder'

targetScope = 'resourceGroup'

// ============================================ //
// RBAC Best Practices for Log Analytics        //
// ============================================ //
// This module configures Log Analytics to use resource-level permissions (RBAC).
// The 'enableLogAccessUsingOnlyResourcePermissions' feature enforces that users/apps
// must have RBAC permissions on the specific resources sending logs, not just workspace access.
//
// Common Log Analytics RBAC roles:
// - Log Analytics Contributor: 92aaf0da-9dab-42b6-94a3-d43ce8d16293 (manage workspace)
// - Log Analytics Reader: 73c42c96-874c-492a-8b58-c20b4869654e (read logs)
// - Monitoring Contributor: 749f88d5-cbae-40b8-bcfc-e573ddc772fa (write metrics/logs)
// - Monitoring Reader: 43d0d8ad-25c7-4714-9337-8ba259a9fe05 (read metrics/logs)
//
// For role assignments, use the separate rbac.bicep module

// ============ //
// Parameters   //
// ============ //

@description('Required. Name of the Log Analytics Workspace.')
param name string

@description('Optional. Location for the workspace.')
param location string = resourceGroup().location

@description('Optional. Tags for the workspace.')
param tags object = {}

@description('Optional. Workspace data retention in days.')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Optional. Daily ingestion limit in GB.')
param dailyQuotaGb int = -1

@description('Optional. Workspace SKU.')
@allowed([
  'PerGB2018'
  'CapacityReservation'
])
param sku string = 'PerGB2018'

@description('Optional. Enable public network access.')
param publicNetworkAccessForIngestion string = 'Enabled'

@description('Optional. Enable public network access for queries.')
param publicNetworkAccessForQuery string = 'Enabled'

// ==================== //
// Resources            //
// ==================== //

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: sku
    }
    retentionInDays: retentionInDays
    workspaceCapping: dailyQuotaGb > 0 ? {
      dailyQuotaGb: dailyQuotaGb
    } : null
    publicNetworkAccessForIngestion: publicNetworkAccessForIngestion
    publicNetworkAccessForQuery: publicNetworkAccessForQuery
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Diagnostic settings for the workspace itself
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: logAnalyticsWorkspace
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// Resource lock
resource lock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: '${name}-lock'
  scope: logAnalyticsWorkspace
  properties: {
    level: 'CanNotDelete'
    notes: 'Prevents accidental deletion of Log Analytics Workspace'
  }
}

// ============ //
// Outputs      //
// ============ //

@description('The resource ID of the Log Analytics Workspace.')
output resourceId string = logAnalyticsWorkspace.id

@description('The name of the Log Analytics Workspace.')
output name string = logAnalyticsWorkspace.name

@description('The workspace ID (GUID) of the Log Analytics Workspace.')
output workspaceId string = logAnalyticsWorkspace.properties.customerId

@description('The location of the Log Analytics Workspace.')
output location string = logAnalyticsWorkspace.location
