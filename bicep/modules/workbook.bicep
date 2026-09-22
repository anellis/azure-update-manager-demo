// Azure Update Manager reporting workbook: blends Azure Resource Graph tiles (the real backing
// store for compliance/patch data) with a Log Analytics tile for the alert signal.
@description('Azure region.')
param location string

@description('Resource name prefix.')
param namePrefix string

@description('Tags to apply to all resources.')
param tags object = {}

@description('Log Analytics workspace resource ID, used for the alert-signal tile.')
param workspaceId string

// Bicep multi-line strings don't support ${} interpolation — use format() with a {0} placeholder for workspaceId.
var serializedWorkbookTemplate = '''
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": { "json": "# Azure Update Manager — Demo Compliance Report\nData sourced from Azure Resource Graph (patch assessment/installation) and Log Analytics (alert signal)." },
      "name": "title"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "Resources | where type == 'microsoft.compute/virtualmachines' | project name, environment = tostring(tags.Environment), os = tostring(tags.OS)",
        "queryType": 1,
        "resourceType": "microsoft.resourcegraph/resources"
      },
      "name": "vm-inventory"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "patchassessmentresources | where type == 'microsoft.compute/virtualmachines/patchassessmentresults' | project id, status = properties.status",
        "queryType": 1,
        "resourceType": "microsoft.resourcegraph/resources"
      },
      "name": "compliance-summary"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "patchassessmentresources | where type == 'microsoft.compute/virtualmachines/patchassessmentresults' | extend criticalCount = toint(properties.availablePatchCountByClassification.critical), securityCount = toint(properties.availablePatchCountByClassification.security) | where criticalCount > 0 or securityCount > 0 | project id, criticalCount, securityCount",
        "queryType": 1,
        "resourceType": "microsoft.resourcegraph/resources"
      },
      "name": "missing-critical-security"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "patchinstallationresources | where type == 'microsoft.compute/virtualmachines/patchinstallationresults' | project id, status = properties.status, startTime = properties.startDateTime | order by startTime desc",
        "queryType": 1,
        "resourceType": "microsoft.resourcegraph/resources"
      },
      "name": "patch-run-history"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "AzureActivity | where OperationNameValue == 'MICROSOFT.MAINTENANCE/APPLYUPDATES/ACTION' | project TimeGenerated, ActivityStatusValue, ResourceId | order by TimeGenerated desc",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "crossComponentResources": [ "{0}" ]
      },
      "name": "alert-signal-activity-log"
    }
  ]
}
'''

var serializedWorkbook = format(serializedWorkbookTemplate, workspaceId)

resource workbook 'Microsoft.Insights/workbooks@2023-06-01' = {
  name: guid('${namePrefix}-update-manager-workbook')
  location: location
  tags: tags
  kind: 'shared'
  properties: {
    displayName: '${namePrefix} Update Manager Demo Report'
    serializedData: serializedWorkbook
    category: 'workbook'
    sourceId: workspaceId
  }
}

output workbookId string = workbook.id
