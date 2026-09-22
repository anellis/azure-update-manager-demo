// Azure Update Manager demo environment — subscription-scope orchestrator.
// Deploy with: az deployment sub create --location eastus2 --template-file main.bicep --parameters main.bicepparam
targetScope = 'subscription'

@description('Azure region for all resources.')
param location string = 'eastus2'

@description('Resource group name.')
param resourceGroupName string = 'rg-aum-demo-eastus2'

@description('Resource name prefix.')
param namePrefix string = 'aumdemo'

@description('Common tags applied to all resources.')
param tags object = {
  Project: 'aum-demo'
  Owner: 'change-me'
  CostCenter: 'demo'
}

@description('Local administrator username for all VMs.')
param adminUsername string

@secure()
@description('Local administrator password for Windows VMs and Linux password-auth fallback. Prefer Key Vault reference or CLI prompt — never commit a value.')
param adminPassword string

@secure()
@description('SSH public key for Linux VMs (used when linuxAuthenticationType is sshPublicKey).')
param sshPublicKey string = ''

@description('Authentication type for Linux VMs.')
@allowed([
  'sshPublicKey'
  'password'
])
param linuxAuthenticationType string = 'sshPublicKey'

@description('Email address to notify on failed patch installation.')
param alertEmail string

@description('VM size for all demo VMs.')
param vmSize string = 'Standard_B2s'

@description('Windows Server marketplace image version. Pin to an older build so pending updates exist for the demo.')
param windowsImageVersion string = 'latest'

@description('Ubuntu marketplace image version. Pin to an older build so pending updates exist for the demo.')
param ubuntuImageVersion string = 'latest'

@description('RHEL marketplace image version. Pin to an older build so pending updates exist for the demo.')
param rhelImageVersion string = 'latest'

var windowsVms = [
  {
    name: 'vm-win22-prod'
    osSku: '2022-datacenter-azure-edition'
    environment: 'Prod'
    patchMode: 'AutomaticByPlatform'
    assessmentMode: 'AutomaticByPlatform'
  }
  {
    name: 'vm-win22-nonprod'
    osSku: '2022-datacenter-azure-edition'
    environment: 'NonProd'
    patchMode: 'AutomaticByPlatform'
    assessmentMode: 'AutomaticByPlatform'
  }
  {
    name: 'vm-win19-prod'
    osSku: '2019-datacenter-gensecond'
    environment: 'Prod'
    patchMode: 'AutomaticByPlatform'
    assessmentMode: 'AutomaticByPlatform'
  }
  {
    name: 'vm-win19-nonprod'
    osSku: '2019-datacenter-gensecond'
    environment: 'NonProd'
    patchMode: 'Manual'
    assessmentMode: 'ImageDefault'
  }
]

var linuxVms = [
  {
    name: 'vm-ubuntu-prod'
    publisher: 'Canonical'
    offer: '0001-com-ubuntu-server-jammy'
    sku: '22_04-lts-gen2'
    environment: 'Prod'
    patchMode: 'AutomaticByPlatform'
    assessmentMode: 'AutomaticByPlatform'
  }
  {
    name: 'vm-ubuntu-nonprod'
    publisher: 'Canonical'
    offer: '0001-com-ubuntu-server-jammy'
    sku: '22_04-lts-gen2'
    environment: 'NonProd'
    patchMode: 'AutomaticByPlatform'
    assessmentMode: 'AutomaticByPlatform'
  }
  {
    name: 'vm-rhel9-prod'
    publisher: 'RedHat'
    offer: 'RHEL'
    sku: '9-lvm-gen2'
    environment: 'Prod'
    patchMode: 'AutomaticByPlatform'
    assessmentMode: 'AutomaticByPlatform'
  }
  {
    name: 'vm-rhel9-nonprod'
    publisher: 'RedHat'
    offer: 'RHEL'
    sku: '9-lvm-gen2'
    environment: 'NonProd'
    patchMode: 'ImageDefault'
    assessmentMode: 'ImageDefault'
  }
]

resource rg 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module network 'modules/network.bicep' = {
  name: 'deploy-network'
  scope: rg
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
  }
}

module loganalytics 'modules/loganalytics.bicep' = {
  name: 'deploy-loganalytics'
  scope: rg
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
  }
}

module automation 'modules/automation.bicep' = {
  name: 'deploy-automation'
  scope: rg
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
  }
}

module winVms 'modules/vm-windows.bicep' = [
  for vm in windowsVms: {
    name: 'deploy-${vm.name}'
    scope: rg
    params: {
      location: location
      vmName: vm.name
      osSku: vm.osSku
      imageVersion: windowsImageVersion
      vmSize: vmSize
      subnetId: network.outputs.subnetId
      environmentTag: vm.environment
      patchMode: vm.patchMode
      assessmentMode: vm.assessmentMode
      adminUsername: adminUsername
      adminPassword: adminPassword
      tags: tags
    }
  }
]

module linuxVmModules 'modules/vm-linux.bicep' = [
  for vm in linuxVms: {
    name: 'deploy-${vm.name}'
    scope: rg
    params: {
      location: location
      vmName: vm.name
      imagePublisher: vm.publisher
      imageOffer: vm.offer
      imageSku: vm.sku
      imageVersion: vm.name == 'vm-rhel9-prod' || vm.name == 'vm-rhel9-nonprod' ? rhelImageVersion : ubuntuImageVersion
      vmSize: vmSize
      subnetId: network.outputs.subnetId
      environmentTag: vm.environment
      patchMode: vm.patchMode
      assessmentMode: vm.assessmentMode
      adminUsername: adminUsername
      adminPasswordOrSshKey: linuxAuthenticationType == 'sshPublicKey' ? sshPublicKey : adminPassword
      authenticationType: linuxAuthenticationType
      tags: tags
    }
  }
]

module maintenanceConfigs 'modules/maintenance-configs.bicep' = {
  name: 'deploy-maintenance-configs'
  scope: rg
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
  }
}

module dynamicScope 'modules/dynamic-scope-assignment.bicep' = {
  name: 'deploy-dynamic-scope'
  params: {
    resourceGroupName: resourceGroupName
    prodMonthlyConfigId: maintenanceConfigs.outputs.prodMonthlyId
    nonProdWeeklyConfigId: maintenanceConfigs.outputs.nonProdWeeklyId
  }
}

// Static/direct assignment on vm-rhel9-prod, to contrast with the dynamic tag-based scope above.
module staticScope 'modules/static-scope-assignment.bicep' = {
  name: 'deploy-static-scope'
  scope: rg
  params: {
    vmName: linuxVms[2].name
    maintenanceConfigurationId: maintenanceConfigs.outputs.prodMonthlyId
  }
  dependsOn: [
    linuxVmModules
  ]
}

module policy 'modules/policy-periodic-assessment.bicep' = {
  name: 'deploy-policy'
  scope: rg
  params: {
    location: location
    namePrefix: namePrefix
  }
  dependsOn: [
    winVms
    linuxVmModules
  ]
}

module resourceGraphQueries 'modules/resourcegraph-queries.bicep' = {
  name: 'deploy-arg-queries'
  params: {
    resourceGroupName: resourceGroupName
    tags: tags
  }
  dependsOn: [
    winVms
    linuxVmModules
  ]
}

module workbook 'modules/workbook.bicep' = {
  name: 'deploy-workbook'
  scope: rg
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
    workspaceId: loganalytics.outputs.workspaceId
  }
}

module alerting 'modules/alerting.bicep' = {
  name: 'deploy-alerting'
  scope: rg
  params: {
    namePrefix: namePrefix
    alertEmail: alertEmail
  }
}

output resourceGroupName string = rg.name
output automationAccountName string = automation.outputs.automationAccountName
output workspaceName string = loganalytics.outputs.workspaceName
