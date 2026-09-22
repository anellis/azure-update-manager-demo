targetScope = 'subscription'

@description('Azure region for the demo environment.')
param location string = 'eastus2'

@description('Target resource group name.')
param resourceGroupName string = 'rg-aum-demo-eastus2'

@description('Resource naming prefix.')
param namePrefix string = 'aumdemo'

@description('Tenant ID recorded in the environment tags and outputs.')
param tenantId string

@description('Subscription ID expected by the deployment.')
param subscriptionId string

@description('Your public IPv4 CIDR, normally a /32, allowed for RDP and SSH.')
param adminPublicIpCidr string

@description('Owner tag value.')
param owner string

@description('Email address for failed patch installation alerts.')
param alertEmail string

@secure()
@description('Local administrator password for the demo VMs.')
param adminPassword string

@secure()
@description('SSH public key for Linux VMs.')
param sshPublicKey string

@description('Linux authentication type.')
@allowed([
  'sshPublicKey'
  'password'
])
param linuxAuthenticationType string = 'sshPublicKey'

@description('Whether to deploy Azure Bastion Developer.')
param deployBastionDeveloper bool = false

@description('Windows image version.')
param windowsImageVersion string = 'latest'

@description('Ubuntu image version.')
param ubuntuImageVersion string = 'latest'

@description('RHEL image version.')
param rhelImageVersion string = 'latest'

@description('Maintenance schedules passed to the maintenance module.')
param schedules array

@description('Common resource tags.')
param tags object = {}

var commonTags = union(tags, {
  Demo: 'true'
  TenantId: tenantId
  SubscriptionId: subscriptionId
})

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: resourceGroupName
  location: location
  tags: commonTags
}

module network 'modules/network.bicep' = {
  name: 'network'
  scope: resourceGroup
  params: {
    location: location
    namePrefix: namePrefix
    adminPublicIpCidr: adminPublicIpCidr
    deployBastionDeveloper: deployBastionDeveloper
    tags: commonTags
  }
}

module vms 'modules/vms.bicep' = {
  name: 'vms'
  scope: resourceGroup
  params: {
    location: location
    subnetId: network.outputs.vmSubnetId
    windowsImageVersion: windowsImageVersion
    ubuntuImageVersion: ubuntuImageVersion
    rhelImageVersion: rhelImageVersion
    adminUsername: 'aumdemoadmin'
    adminPassword: adminPassword
    sshPublicKey: sshPublicKey
    linuxAuthenticationType: linuxAuthenticationType
    owner: owner
    tags: commonTags
  }
}

module law 'modules/law.bicep' = {
  name: 'law'
  scope: resourceGroup
  params: {
    location: location
    namePrefix: namePrefix
    vmIds: vms.outputs.allVmIds
    tags: commonTags
  }
}

module maintenance 'modules/maintenance-config.bicep' = {
  name: 'maintenance'
  scope: resourceGroup
  params: {
    location: location
    schedules: schedules
    tags: commonTags
  }
}

module dynamicScope 'modules/dynamic-scope.bicep' = {
  name: 'dynamic-scope'
  params: {
    location: location
    resourceGroupName: resourceGroupName
    maintenanceConfigurationIds: maintenance.outputs.configurationIds
    environments: [for schedule in schedules: schedule.environment]
  }
}

module staticAssignment 'modules/static-assignment.bicep' = {
  name: 'static-assignment'
  scope: resourceGroup
  params: {
    vmName: 'aumdemo-rhel9-nonprod-01'
    maintenanceConfigurationId: maintenance.outputs.configurationIds[1]
  }
  dependsOn: [
    vms
  ]
}

module policy 'modules/policy.bicep' = {
  name: 'policy'
  scope: resourceGroup
  params: {
    location: location
    namePrefix: namePrefix
  }
  dependsOn: [
    vms
  ]
}

module alerts 'modules/alerts.bicep' = {
  name: 'alerts'
  scope: resourceGroup
  params: {
    namePrefix: namePrefix
    alertEmail: alertEmail
    alertScope: resourceGroup.id
  }
}

module prepost 'modules/prepost-stub.bicep' = {
  name: 'prepost-stub'
  scope: resourceGroup
  params: {
    location: location
    namePrefix: namePrefix
    tags: commonTags
  }
}

output resourceGroupId string = resourceGroup.id
output resourceGroupPortalUrl string = 'https://portal.azure.com/#@/resource${resourceGroup.id}/overview'
output vnetId string = network.outputs.vnetId
output vnetPortalUrl string = 'https://portal.azure.com/#@/resource${network.outputs.vnetId}/overview'
output vmIds array = vms.outputs.allVmIds
output vmPortalUrls array = vms.outputs.allVmPortalUrls
output workspaceId string = law.outputs.workspaceId
output workspacePortalUrl string = law.outputs.workspacePortalUrl
output maintenanceConfigurationIds array = maintenance.outputs.configurationIds
output maintenanceConfigurationPortalUrls array = maintenance.outputs.configurationPortalUrls
output dynamicAssignmentIds array = dynamicScope.outputs.assignmentIds
output dynamicAssignmentPortalUrls array = dynamicScope.outputs.assignmentPortalUrls
output staticAssignmentId string = staticAssignment.outputs.assignmentId
output staticAssignmentPortalUrl string = staticAssignment.outputs.assignmentPortalUrl
output policyAssignmentId string = policy.outputs.assignmentId
output policyPortalUrl string = policy.outputs.assignmentPortalUrl
output actionGroupId string = alerts.outputs.actionGroupId
output failedPatchAlertId string = alerts.outputs.failedPatchAlertId
output automationAccountId string = prepost.outputs.automationAccountId
output runbookId string = prepost.outputs.runbookId