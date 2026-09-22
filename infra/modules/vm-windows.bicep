@description('Azure region for the VM.')
param location string

@description('Windows VM name.')
param vmName string

@description('Windows Server marketplace image SKU.')
param imageSku string

@description('Marketplace image version. Use latest or pin a known image version.')
param imageVersion string = 'latest'

@description('VM size.')
param vmSize string = 'Standard_B2s'

@description('Subnet resource ID for the VM network interface.')
param subnetId string

@description('Local administrator username.')
param adminUsername string

@secure()
@description('Local administrator password.')
param adminPassword string

@description('Patch installation mode. AutomaticByPlatform is required for Customer Managed Schedules.')
@allowed([
  'AutomaticByOS'
  'AutomaticByPlatform'
  'Manual'
])
param patchMode string = 'AutomaticByPlatform'

@description('Patch assessment mode. ImageDefault intentionally leaves periodic assessment disabled.')
@allowed([
  'ImageDefault'
  'AutomaticByPlatform'
])
param assessmentMode string = 'AutomaticByPlatform'

@description('Whether to bypass Azure platform safety checks when a user schedule is used.')
param bypassPlatformSafetyChecksOnUserSchedule bool = false

@description('Environment tag value.')
param environment string

@description('Owner tag value.')
param owner string

@description('Patch group tag value.')
param patchGroup string

@description('Additional tags.')
param tags object = {}

var mergedTags = union(tags, {
  Environment: environment
  Owner: owner
  PatchGroup: patchGroup
  Demo: 'true'
})

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
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

resource vm 'Microsoft.Compute/virtualMachines@2024-11-01' = {
  name: vmName
  location: location
  tags: mergedTags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: imageSku
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
        provisionVMAgent: true
        enableAutomaticUpdates: false
        patchSettings: {
          patchMode: patchMode
          assessmentMode: assessmentMode
          enableHotpatching: false
          automaticByPlatformSettings: {
            bypassPlatformSafetyChecksOnUserSchedule: bypassPlatformSafetyChecksOnUserSchedule
          }
        }
      }
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
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

resource azureMonitorAgent 'Microsoft.Compute/virtualMachines/extensions@2024-11-01' = {
  parent: vm
  name: 'AzureMonitorWindowsAgent'
  location: location
  tags: mergedTags
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: {}
  }
}

output vmId string = vm.id
output vmName string = vm.name
output vmPrincipalId string = vm.identity.principalId
output vmPortalUrl string = 'https://portal.azure.com/#@/resource${vm.id}/overview'