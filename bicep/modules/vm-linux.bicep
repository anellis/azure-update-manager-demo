// Linux VM (Ubuntu 22.04 or RHEL 9) with configurable patch orchestration mode for the AUM demo.
@description('Azure region.')
param location string

@description('VM name.')
param vmName string

@description('Marketplace image publisher, e.g. Canonical or RedHat.')
param imagePublisher string

@description('Marketplace image offer, e.g. 0001-com-ubuntu-server-jammy or RHEL.')
param imageOffer string

@description('Marketplace image SKU, e.g. 22_04-lts-gen2 or 9-lvm-gen2.')
param imageSku string

@description('Marketplace image version. Pin to an older build so pending updates exist for the demo.')
param imageVersion string = 'latest'

@description('VM plan required for some PAYG marketplace images (e.g. RHEL). Leave null for Ubuntu.')
param plan object?

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

@description('Patch mode: AutomaticByPlatform (required for Customer Managed Schedules or Azure-orchestrated) or ImageDefault (manual/distro-managed).')
@allowed([
  'AutomaticByPlatform'
  'ImageDefault'
])
param patchMode string

@description('Assessment mode: AutomaticByPlatform (periodic assessment ON) or ImageDefault (periodic assessment OFF).')
@allowed([
  'AutomaticByPlatform'
  'ImageDefault'
])
param assessmentMode string

@description('Local administrator username.')
param adminUsername string

@secure()
@description('SSH public key (preferred) or password, depending on authenticationType.')
param adminPasswordOrSshKey string

@description('Authentication type for the Linux VM.')
@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string = 'sshPublicKey'

@description('Tags to apply, merged with the Environment tag.')
param tags object = {}

var mergedTags = union(tags, {
  Environment: environmentTag
  OS: 'Linux'
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
  plan: plan
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
      adminPassword: authenticationType == 'password' ? adminPasswordOrSshKey : null
      linuxConfiguration: {
        disablePasswordAuthentication: authenticationType == 'sshPublicKey'
        ssh: authenticationType == 'sshPublicKey' ? {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminPasswordOrSshKey
            }
          ]
        } : null
        provisionVMAgent: true
        patchSettings: {
          patchMode: patchMode
          assessmentMode: assessmentMode
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
