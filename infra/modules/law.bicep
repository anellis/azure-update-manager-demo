@description('Azure region for the workspace and data collection rule.')
param location string

@description('Prefix used for resource names.')
param namePrefix string

@description('VM resource IDs that should send guest telemetry to the workspace.')
param vmIds array

@description('Log Analytics retention in days.')
param retentionInDays int = 30

@description('Common resource tags.')
param tags object = {}

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${namePrefix}-law'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: '${namePrefix}-dcr'
  location: location
  kind: 'All'
  tags: tags
  properties: {
    dataSources: {
      performanceCounters: [
        {
          name: 'demo-performance'
          streams: [
            'Microsoft-Perf'
          ]
          samplingFrequencyInSeconds: 60
          counterSpecifiers: [
            '\\Processor(_Total)\\% Processor Time'
            '\\Memory\\% Committed Bytes In Use'
            '\\LogicalDisk(_Total)\\% Free Space'
          ]
        }
      ]
      windowsEventLogs: [
        {
          name: 'demo-windows-events'
          streams: [
            'Microsoft-WindowsEvent'
          ]
          xPathQueries: [
            'System!*[System[(Level=1 or Level=2 or Level=3)]]'
            'Application!*[System[(Level=1 or Level=2 or Level=3)]]'
          ]
        }
      ]
      syslog: [
        {
          name: 'demo-syslog'
          streams: [
            'Microsoft-Syslog'
          ]
          facilityNames: [
            'auth'
            'authpriv'
            'daemon'
            'syslog'
          ]
          logLevels: [
            'Warning'
            'Error'
            'Critical'
            'Alert'
            'Emergency'
          ]
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          name: 'demo-law-destination'
          workspaceResourceId: workspace.id
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-Perf'
          'Microsoft-WindowsEvent'
          'Microsoft-Syslog'
        ]
        destinations: [
          'demo-law-destination'
        ]
      }
    ]
  }
}

resource vms 'Microsoft.Compute/virtualMachines@2024-11-01' existing = [for vmId in vmIds: {
  name: last(split(vmId, '/'))
}]

resource dataCollectionRuleAssociations 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11' = [for (vmId, index) in vmIds: {
  name: '${namePrefix}-${uniqueString(vmId)}-dcr'
  scope: vms[index]
  properties: {
    dataCollectionRuleId: dataCollectionRule.id
    description: 'Azure Monitor Agent association for the AUM demo VM.'
  }
}]

output workspaceId string = workspace.id
output workspaceName string = workspace.name
output dataCollectionRuleId string = dataCollectionRule.id
output workspacePortalUrl string = 'https://portal.azure.com/#@/resource${workspace.id}/overview'