// Static/direct configuration assignment on a single VM, to contrast with dynamic tag-based scoping.
@description('Name of the VM to assign directly (e.g. vm-rhel9-prod).')
param vmName string

@description('Resource ID of the maintenance configuration to assign (e.g. Prod-Monthly-Sunday-2AM).')
param maintenanceConfigurationId string

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' existing = {
  name: vmName
}

resource staticAssignment 'Microsoft.Maintenance/configurationAssignments@2023-04-01' = {
  name: 'staticscope-${vmName}'
  location: vm.location
  scope: vm
  properties: {
    maintenanceConfigurationId: maintenanceConfigurationId
    resourceId: vm.id
  }
}
