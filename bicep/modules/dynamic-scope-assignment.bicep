// Dynamic scope: VMs join a maintenance configuration by Environment tag, not by resource ID.
// Must be deployed at subscription scope.
targetScope = 'subscription'

@description('Resource group name containing the demo VMs.')
param resourceGroupName string

@description('Resource ID of the Prod-Monthly-Sunday-2AM maintenance configuration.')
param prodMonthlyConfigId string

@description('Resource ID of the NonProd-Weekly-Friday-10PM maintenance configuration.')
param nonProdWeeklyConfigId string

resource dynamicScopeProd 'Microsoft.Maintenance/configurationAssignments@2023-04-01' = {
  name: 'dynscope-prod-monthly'
  location: deployment().location
  properties: {
    maintenanceConfigurationId: prodMonthlyConfigId
    resourceId: subscription().id
    filter: {
      resourceTypes: [
        'Microsoft.Compute/virtualMachines'
      ]
      resourceGroups: [
        resourceGroupName
      ]
      osTypes: [
        'Windows'
        'Linux'
      ]
      tagSettings: {
        tags: {
          Environment: [
            'Prod'
          ]
        }
        filterOperator: 'All'
      }
    }
  }
}

resource dynamicScopeNonProd 'Microsoft.Maintenance/configurationAssignments@2023-04-01' = {
  name: 'dynscope-nonprod-weekly'
  location: deployment().location
  properties: {
    maintenanceConfigurationId: nonProdWeeklyConfigId
    resourceId: subscription().id
    filter: {
      resourceTypes: [
        'Microsoft.Compute/virtualMachines'
      ]
      resourceGroups: [
        resourceGroupName
      ]
      osTypes: [
        'Windows'
        'Linux'
      ]
      tagSettings: {
        tags: {
          Environment: [
            'NonProd'
          ]
        }
        filterOperator: 'All'
      }
    }
  }
}
