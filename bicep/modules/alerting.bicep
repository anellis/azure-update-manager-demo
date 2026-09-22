// Action group + activity log alert firing when a maintenance/patch install run fails.
@description('Resource name prefix.')
param namePrefix string

@description('Email address to notify on failed patch installation.')
param alertEmail string

resource actionGroup 'Microsoft.Insights/actionGroups@2023-09-01-preview' = {
  name: '${namePrefix}-ag-patchfail'
  location: 'global'
  properties: {
    groupShortName: 'aumPatchFail'
    enabled: true
    emailReceivers: [
      {
        name: 'demo-owner'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

resource failedPatchAlert 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: '${namePrefix}-alert-patch-install-failed'
  location: 'global'
  properties: {
    enabled: true
    scopes: [
      resourceGroup().id
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'Administrative'
        }
        {
          field: 'operationName'
          equals: 'Microsoft.Maintenance/applyUpdates/action'
        }
        {
          field: 'status'
          equals: 'Failed'
        }
      ]
    }
    actions: {
      actionGroups: [
        {
          actionGroupId: actionGroup.id
        }
      ]
    }
  }
}

output actionGroupId string = actionGroup.id
