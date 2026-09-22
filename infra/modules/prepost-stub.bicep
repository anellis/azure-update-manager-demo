@description('Azure region for the Automation Account.')
param location string

@description('Resource name prefix.')
param namePrefix string

@description('Common resource tags.')
param tags object = {}

resource automationAccount 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: '${namePrefix}-aa'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Basic'
    }
    publicNetworkAccess: true
  }
}

resource runbook 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = {
  parent: automationAccount
  name: 'PrePostPatch-TalkTrack-Stub'
  location: location
  tags: union(tags, {
    DemoArtifact: 'true'
  })
  properties: {
    runbookType: 'PowerShell'
    description: 'TALK-TRACK ARTIFACT ONLY. This stub is not wired to a production application, load balancer, or database.'
    logProgress: true
    logVerbose: false
  }
}

output automationAccountId string = automationAccount.id
output runbookId string = runbook.id
output automationAccountPortalUrl string = 'https://portal.azure.com/#@/resource${automationAccount.id}/overview'
output runbookPortalUrl string = 'https://portal.azure.com/#@/resource${runbook.id}/overview'