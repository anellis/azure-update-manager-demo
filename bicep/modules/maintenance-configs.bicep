// Two Microsoft.Maintenance/maintenanceConfigurations: Prod (monthly) and NonProd (weekly).
// NOTE: recurEvery syntax ("Month Fourth Sunday", "1Week Friday") should be re-verified against
// current Microsoft.Maintenance docs before deploying — this format has had minor revisions.
@description('Azure region.')
param location string

@description('Resource name prefix.')
param namePrefix string

@description('Tags to apply to all resources.')
param tags object = {}

@description('IANA/Windows time zone name for both schedules.')
param timeZone string = 'Eastern Standard Time'

resource prodMonthly 'Microsoft.Maintenance/maintenanceConfigurations@2023-04-01' = {
  name: 'Prod-Monthly-Sunday-2AM'
  location: location
  tags: union(tags, { Environment: 'Prod' })
  properties: {
    maintenanceScope: 'InGuestPatch'
    extensionProperties: {
      InGuestPatchMode: 'User'
    }
    maintenanceWindow: {
      startDateTime: '2026-09-27 02:00'
      duration: '03:00'
      timeZone: timeZone
      recurEvery: 'Month Fourth Sunday'
    }
    installPatches: {
      rebootSetting: 'IfRequired'
      windowsParameters: {
        classificationsToInclude: [
          'Critical'
          'Security'
        ]
      }
      linuxParameters: {
        classificationsToInclude: [
          'Critical'
          'Security'
        ]
      }
    }
  }
}

resource nonProdWeekly 'Microsoft.Maintenance/maintenanceConfigurations@2023-04-01' = {
  name: 'NonProd-Weekly-Friday-10PM'
  location: location
  tags: union(tags, { Environment: 'NonProd' })
  properties: {
    maintenanceScope: 'InGuestPatch'
    extensionProperties: {
      InGuestPatchMode: 'User'
    }
    maintenanceWindow: {
      startDateTime: '2026-09-25 22:00'
      duration: '04:00'
      timeZone: timeZone
      recurEvery: '1Week Friday'
    }
    installPatches: {
      rebootSetting: 'Always'
      windowsParameters: {
        classificationsToInclude: [
          'Critical'
          'Security'
          'Other'
        ]
      }
      linuxParameters: {
        classificationsToInclude: [
          'Critical'
          'Security'
          'Other'
        ]
      }
    }
  }
}

output prodMonthlyId string = prodMonthly.id
output nonProdWeeklyId string = nonProdWeekly.id
