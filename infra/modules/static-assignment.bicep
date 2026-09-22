@description('Name of the VM receiving the direct assignment.')
param vmName string

@description('Maintenance configuration resource ID to assign directly.')
param maintenanceConfigurationId string

resource vm 'Microsoft.Compute/virtualMachines@2024-11-01' existing = {
  name: vmName
}

resource assignment 'Microsoft.Maintenance/configurationAssignments@2023-04-01' = {
  name: 'static-${vmName}'
  scope: vm
  properties: {
    maintenanceConfigurationId: maintenanceConfigurationId
    resourceId: vm.id
  }
}

output assignmentId string = assignment.id
output assignmentPortalUrl string = 'https://portal.azure.com/#@/resource${assignment.id}/overview'