@description('Azure region for the VM.')
param location string

@description('Linux VM name.')
param vmName string

@description('Marketplace image publisher, such as Canonical or RedHat.')
param imagePublisher string

@description('Marketplace image offer.')
param imageOffer string

@description('Marketplace image SKU.')
param imageSku string

@description('Marketplace image version. Use latest or pin a known image version.')
param imageVersion string = 'latest'

@description('Optional marketplace plan metadata, required for some PAYG images such as RHEL.')
param plan object?

@description('VM size.')
param vmSize string = 'Standard_B2s'

@description('Subnet resource ID for the VM network interface.')
param subnetId string

@description('Local administrator username.')
param adminUsername string

@secure()
@description('Local administrator password, used only when authenticationType is password.')
param adminPassword string

@secure()
@description('SSH public key, used only when authenticationType is sshPublicKey.')
param sshPublicKey string

@description('Linux authentication mode.')
@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string = 'sshPublicKey'

@description('Patch installation mode. AutomaticByPlatform is required for Customer Managed Schedules.')
@allowed([
  'ImageDefault'
  'AutomaticByPlatform'
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
  plan: plan
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
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
      adminPassword: authenticationType == 'password' ? adminPassword : null
      linuxConfiguration: {
        disablePasswordAuthentication: authenticationType == 'sshPublicKey'
        provisionVMAgent: true
        ssh: authenticationType == 'sshPublicKey' ? {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        } : null
        patchSettings: {
          patchMode: patchMode
          assessmentMode: assessmentMode
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
  name: 'AzureMonitorLinuxAgent'
  location: location
  tags: mergedTags
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
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