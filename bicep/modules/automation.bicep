// Automation account hosting a pre/post maintenance event STUB runbook.
// Runbook content is published post-deploy by scripts/deploy.ps1 (az automation runbook replace-content),
// since Bicep cannot reliably inline multi-line script content.
@description('Azure region.')
param location string

@description('Resource name prefix.')
param namePrefix string

@description('Tags to apply to all resources.')
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

resource prePostRunbook 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = {
  parent: automationAccount
  name: 'PrePostPatch-Stub'
  location: location
  tags: tags
  properties: {
    runbookType: 'PowerShell'
    description: 'DEMO STUB ONLY: illustrates pre/post maintenance event hooks for app-aware patching. Not wired to a real application.'
    logProgress: true
    logVerbose: false
  }
}

output automationAccountName string = automationAccount.name
output automationAccountPrincipalId string = automationAccount.identity.principalId
output runbookName string = prePostRunbook.name
