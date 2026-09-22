@description('Azure region for the VMs.')
param location string

@description('Subnet resource ID for all VM network interfaces.')
param subnetId string

@description('Common VM size.')
param vmSize string = 'Standard_B2s'

@description('Windows Server image version.')
param windowsImageVersion string = 'latest'

@description('Ubuntu 22.04 image version.')
param ubuntuImageVersion string = 'latest'

@description('RHEL 9 image version.')
param rhelImageVersion string = 'latest'

@description('Local administrator username.')
param adminUsername string

@secure()
@description('Windows administrator password and Linux password-auth fallback.')
param adminPassword string

@secure()
@description('SSH public key for Linux VMs.')
param sshPublicKey string

@description('Linux authentication mode.')
@allowed([
  'sshPublicKey'
  'password'
])
param linuxAuthenticationType string = 'sshPublicKey'

@description('Owner tag value for the demo VMs.')
param owner string

@description('Additional tags applied to all VMs.')
param tags object = {}

var windowsVms = [
  {
    name: 'aumdemo-win22-prod-01'
    sku: '2022-datacenter-azure-edition'
    patchGroup: 'Prod-CustomerManaged'
    patchMode: 'AutomaticByPlatform'
    assessmentMode: 'AutomaticByPlatform'
    bypass: true
  }
  {
    name: 'aumdemo-win22-prod-02'
    sku: '2022-datacenter-azure-edition'
    patchGroup: 'Prod-AzureOrchestrated'
    patchMode: 'AutomaticByPlatform'
    assessmentMode: 'AutomaticByPlatform'
    bypass: false
  }
  {
    name: 'aumdemo-win19-prod-01'
    sku: '2019-datacenter-gensecond'
    patchGroup: 'Prod-Manual'
    patchMode: 'Manual'
    assessmentMode: 'AutomaticByPlatform'
    bypass: false
  }
]

var linuxVms = [
  {
    name: 'aumdemo-ubuntu22-nonprod-01'
    publisher: 'Canonical'
    offer: '0001-com-ubuntu-server-jammy'
    sku: '22_04-lts-gen2'
    version: ubuntuImageVersion
    patchGroup: 'NonProd-CustomerManaged'
    patchMode: 'AutomaticByPlatform'
    assessmentMode: 'AutomaticByPlatform'
    bypass: true
    plan: null
  }
  {
    name: 'aumdemo-ubuntu22-nonprod-02'
    publisher: 'Canonical'
    offer: '0001-com-ubuntu-server-jammy'
    sku: '22_04-lts-gen2'
    version: ubuntuImageVersion
    patchGroup: 'NonProd-AzureOrchestrated'
    patchMode: 'AutomaticByPlatform'
    assessmentMode: 'AutomaticByPlatform'
    bypass: false
    plan: null
  }
  {
    name: 'aumdemo-rhel9-nonprod-01'
    publisher: 'RedHat'
    offer: 'RHEL'
    sku: '9-lvm-gen2'
    version: rhelImageVersion
    patchGroup: 'NonProd-AssessmentOff'
    patchMode: 'ImageDefault'
    assessmentMode: 'ImageDefault'
    bypass: false
    plan: {
      name: '9-lvm-gen2'
      product: 'RHEL'
      publisher: 'RedHat'
    }
  }
]

module windows 'vm-windows.bicep' = [for vm in windowsVms: {
  name: 'deploy-${vm.name}'
  params: {
    location: location
    vmName: vm.name
    imageSku: vm.sku
    imageVersion: windowsImageVersion
    vmSize: vmSize
    subnetId: subnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
    patchMode: vm.patchMode
    assessmentMode: vm.assessmentMode
    bypassPlatformSafetyChecksOnUserSchedule: vm.bypass
    environment: 'Prod'
    owner: owner
    patchGroup: vm.patchGroup
    tags: tags
  }
}]

module linux 'vm-linux.bicep' = [for vm in linuxVms: {
  name: 'deploy-${vm.name}'
  params: {
    location: location
    vmName: vm.name
    imagePublisher: vm.publisher
    imageOffer: vm.offer
    imageSku: vm.sku
    imageVersion: vm.version
    plan: vm.plan
    vmSize: vmSize
    subnetId: subnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
    sshPublicKey: sshPublicKey
    authenticationType: linuxAuthenticationType
    patchMode: vm.patchMode
    assessmentMode: vm.assessmentMode
    bypassPlatformSafetyChecksOnUserSchedule: vm.bypass
    environment: 'NonProd'
    owner: owner
    patchGroup: vm.patchGroup
    tags: tags
  }
}]

output windowsVmIds array = [
  windows[0].outputs.vmId
  windows[1].outputs.vmId
  windows[2].outputs.vmId
]
output linuxVmIds array = [
  linux[0].outputs.vmId
  linux[1].outputs.vmId
  linux[2].outputs.vmId
]
output allVmIds array = [
  windows[0].outputs.vmId
  windows[1].outputs.vmId
  windows[2].outputs.vmId
  linux[0].outputs.vmId
  linux[1].outputs.vmId
  linux[2].outputs.vmId
]
output rhelVmId string = linux[2].outputs.vmId
output allVmPortalUrls array = [
  windows[0].outputs.vmPortalUrl
  windows[1].outputs.vmPortalUrl
  windows[2].outputs.vmPortalUrl
  linux[0].outputs.vmPortalUrl
  linux[1].outputs.vmPortalUrl
  linux[2].outputs.vmPortalUrl
]