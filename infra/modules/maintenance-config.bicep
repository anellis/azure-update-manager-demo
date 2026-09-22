@description('Azure region for the maintenance configurations.')
param location string

@description('Maintenance configuration definitions. Each object must contain name, visibility, startDateTime, duration, timeZone, recurEvery, rebootSetting, windowsClassifications, and linuxClassifications.')
param schedules array

@description('Common resource tags.')
param tags object = {}

resource maintenanceConfigurations 'Microsoft.Maintenance/maintenanceConfigurations@2023-04-01' = [for schedule in schedules: {
  name: schedule.name
  location: location
  tags: union(tags, {
    Environment: schedule.environment
    Demo: 'true'
  })
  properties: {
    maintenanceScope: 'InGuestPatch'
    visibility: schedule.visibility
    extensionProperties: {
      InGuestPatchMode: 'User'
    }
    maintenanceWindow: {
      startDateTime: schedule.startDateTime
      duration: schedule.duration
      timeZone: schedule.timeZone
      recurEvery: schedule.recurEvery
    }
    installPatches: {
      rebootSetting: schedule.rebootSetting
      windowsParameters: {
        classificationsToInclude: schedule.windowsClassifications
      }
      linuxParameters: {
        classificationsToInclude: schedule.linuxClassifications
      }
    }
  }
}]

output configurationIds array = [for (schedule, index) in schedules: maintenanceConfigurations[index].id]
output configurationNames array = [for schedule in schedules: schedule.name]
output configurationPortalUrls array = [for (schedule, index) in schedules: 'https://portal.azure.com/#@/resource${maintenanceConfigurations[index].id}/overview']