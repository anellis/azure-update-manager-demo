@description('Resource name prefix.')
param namePrefix string

@description('Email address that receives failed patch installation notifications.')
param alertEmail string

@description('Resource group scope for the failed patch installation alert.')
param alertScope string

resource actionGroup 'Microsoft.Insights/actionGroups@2023-09-01-preview' = {
  name: '${namePrefix}-patch-failures'
  location: 'global'
  properties: {
    groupShortName: 'AUMFail'
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
  name: '${namePrefix}-failed-patch-install'
  location: 'global'
  properties: {
    enabled: true
    scopes: [
      alertScope
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'Administrative'
        }
        {
          field: 'operationName'
          equals: 'Microsoft.Maintenance/applyUpdates/write'
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
    description: 'Notifies the demo owner when an Update Manager patch installation operation fails.'
  }
}

output actionGroupId string = actionGroup.id
output failedPatchAlertId string = failedPatchAlert.id
output actionGroupPortalUrl string = 'https://portal.azure.com/#@/resource${actionGroup.id}/overview'
output failedPatchAlertPortalUrl string = 'https://portal.azure.com/#@/resource${failedPatchAlert.id}/overview'
