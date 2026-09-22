// Windows Server VM with configurable patch orchestration mode for the AUM demo.
@description('Azure region.')
param location string

@description('VM name.')
param vmName string

@description('Windows Server marketplace SKU, e.g. 2022-datacenter-azure-edition or 2019-datacenter-gensecond.')
param osSku string

@description('Marketplace image version. Pin to an older build so pending updates exist for the demo.')
param imageVersion string = 'latest'

@description('VM size.')
param vmSize string = 'Standard_B2s'

@description('Subnet resource ID to attach the NIC to.')
param subnetId string

@description('Environment tag value: Prod or NonProd.')
@allowed([
  'Prod'
  'NonProd'
])
param environmentTag string

@description('Patch mode: AutomaticByPlatform (required for Customer Managed Schedules or Azure-orchestrated) or Manual.')
@allowed([
  'AutomaticByPlatform'
  'Manual'
])
param patchMode string

@description('Assessment mode: AutomaticByPlatform (periodic assessment ON) or ImageDefault (periodic assessment OFF).')
@allowed([
  'AutomaticByPlatform'
  'ImageDefault'
])
param assessmentMode string

@description('Set true only for VMs that should be scheduled via Customer Managed Schedules (requires patch mode AutomaticByPlatform and no automatic-by-platform Azure orchestration side effects to worry about — this just documents intent via tag).')
param bypassPlatformSafetyNetOnUserSchedule bool = false

@description('Local administrator username.')
param adminUsername string

@secure()
@description('Local administrator password.')
param adminPassword string

@description('Tags to apply, merged with the Environment tag.')
param tags object = {}

var mergedTags = union(tags, {
  Environment: environmentTag
  OS: 'Windows'
  DemoRole: 'aum-update-manager-demo'
})

resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: '${vmName}-nic'
  location: location
  tags: mergedTags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  tags: mergedTags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: osSku
        version: imageVersion
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: false
        provisionVMAgent: true
        patchSettings: {
          patchMode: patchMode
          assessmentMode: assessmentMode
          enableHotpatching: false
          automaticByPlatformSettings: patchMode == 'AutomaticByPlatform' ? {
            bypassPlatformSafetyChecksOnUserSchedule: bypassPlatformSafetyNetOnUserSchedule
          } : null
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

output vmId string = vm.id
output vmName string = vm.name
