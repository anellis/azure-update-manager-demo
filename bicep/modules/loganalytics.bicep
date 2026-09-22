@description('Azure region.')
param location string

@description('Resource name prefix.')
param namePrefix string

@description('Tags to apply to all resources.')
param tags object = {}

@description('Log retention in days.')
param retentionInDays int = 30

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${namePrefix}-law'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
  }
}

output workspaceId string = law.id
output workspaceName string = law.name
output customerId string = law.properties.customerId
