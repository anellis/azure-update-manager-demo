targetScope = 'subscription'

@description('Azure region used by the dynamic assignment resources.')
param location string

@description('Resource group name containing the demo VMs.')
param resourceGroupName string

@description('Maintenance configuration resource IDs to assign dynamically.')
param maintenanceConfigurationIds array

@description('Environment tag values corresponding to each maintenance configuration ID.')
param environments array

resource dynamicAssignments 'Microsoft.Maintenance/configurationAssignments@2023-04-01' = [for (configurationId, index) in maintenanceConfigurationIds: {
  name: 'dynamic-${index}-${uniqueString(configurationId, resourceGroupName)}'
  location: location
  properties: {
    maintenanceConfigurationId: configurationId
    filter: {
      locations: [
        location
      ]
      resourceGroups: [
        resourceGroupName
      ]
      resourceTypes: [
        'Microsoft.Compute/virtualMachines'
      ]
      osTypes: [
        'Windows'
        'Linux'
      ]
      tagSettings: {
        tags: {
          Environment: [
            environments[index]
          ]
        }
        filterOperator: 'All'
      }
    }
  }
}]

output assignmentIds array = [for (configurationId, index) in maintenanceConfigurationIds: dynamicAssignments[index].id]
output assignmentPortalUrls array = [for (configurationId, index) in maintenanceConfigurationIds: 'https://portal.azure.com/#@/resource${dynamicAssignments[index].id}/overview']