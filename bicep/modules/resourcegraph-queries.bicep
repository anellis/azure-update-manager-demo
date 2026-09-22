// Saved Azure Resource Graph queries backing the reporting workbook.
// Validate exact column names in Resource Graph Explorer before the demo — these tables
// (patchassessmentresources / patchinstallationresources) are Update-Manager-specific and
// their schema has changed across API versions.
targetScope = 'subscription'

@description('Resource group name containing the demo VMs, used to scope queries.')
param resourceGroupName string

@description('Tags to apply to all resources.')
param tags object = {}

resource complianceSummary 'Microsoft.ResourceGraph/queries@2024-04-01' = {
  name: 'aum-demo-compliance-summary'
  location: 'global'
  tags: tags
  properties: {
    description: 'Overall per-VM patch compliance status across the demo estate.'
    // Bicep multi-line strings don't support ${} interpolation — use format() with {0} placeholders.
    query: format('''
patchassessmentresources
| where type == "microsoft.compute/virtualmachines/patchassessmentresults"
| where id contains "{0}"
| extend vmName = extract("virtualMachines/([^/]+)", 1, id)
| project vmName, status = properties.status, lastAssessedTime = properties.lastModifiedDateTime, criticalCount = properties.availablePatchCountByClassification.critical, securityCount = properties.availablePatchCountByClassification.security
| order by vmName asc
''', resourceGroupName)
    resultFormat: 'table'
  }
}

resource missingCriticalSecurity 'Microsoft.ResourceGraph/queries@2024-04-01' = {
  name: 'aum-demo-missing-critical-security'
  location: 'global'
  tags: tags
  properties: {
    description: 'VMs with one or more pending Critical or Security classified patches.'
    query: format('''
patchassessmentresources
| where type == "microsoft.compute/virtualmachines/patchassessmentresults"
| where id contains "{0}"
| extend vmName = extract("virtualMachines/([^/]+)", 1, id)
| extend criticalCount = toint(properties.availablePatchCountByClassification.critical), securityCount = toint(properties.availablePatchCountByClassification.security)
| where criticalCount > 0 or securityCount > 0
| project vmName, criticalCount, securityCount, status = properties.status
| order by criticalCount desc, securityCount desc
''', resourceGroupName)
    resultFormat: 'table'
  }
}

resource patchRunHistory 'Microsoft.ResourceGraph/queries@2024-04-01' = {
  name: 'aum-demo-patch-run-history'
  location: 'global'
  tags: tags
  properties: {
    description: 'Recent patch installation runs and their outcome per VM.'
    query: format('''
patchinstallationresources
| where type == "microsoft.compute/virtualmachines/patchinstallationresults"
| where id contains "{0}"
| extend vmName = extract("virtualMachines/([^/]+)", 1, id)
| project vmName, status = properties.status, startTime = properties.startDateTime, installedPatchCount = properties.installedPatchCount, rebootStatus = properties.rebootStatus
| order by startTime desc
''', resourceGroupName)
    resultFormat: 'table'
  }
}

resource byEnvironmentTag 'Microsoft.ResourceGraph/queries@2024-04-01' = {
  name: 'aum-demo-compliance-by-environment'
  location: 'global'
  tags: tags
  properties: {
    description: 'Compliance rollup joined against the Environment=Prod/NonProd tag, to contrast dynamic scope groups.'
    query: format('''
Resources
| where type == "microsoft.compute/virtualmachines"
| where resourceGroup =~ "{0}"
| project vmId = id, vmName = name, environment = tostring(tags.Environment)
| join kind=leftouter (
    patchassessmentresources
    | where type == "microsoft.compute/virtualmachines/patchassessmentresults"
    | extend vmId = tostring(split(id, "/patchAssessmentResults/")[0])
    | project vmId, status = properties.status
) on vmId
| project vmName, environment, status
| order by environment asc, vmName asc
''', resourceGroupName)
    resultFormat: 'table'
  }
}
