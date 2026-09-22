@description('Azure region for the network resources.')
param location string

@description('Prefix used for resource names.')
param namePrefix string

@description('CIDR block allowed to reach RDP and SSH. Supply your public IP as /32.')
param adminPublicIpCidr string

@description('Virtual network address space.')
param vnetAddressPrefix string = '10.60.0.0/24'

@description('VM subnet address space.')
param vmSubnetAddressPrefix string = '10.60.0.0/26'

@description('Whether to deploy Azure Bastion Developer for browser-based VM access.')
param deployBastionDeveloper bool = false

@description('Common resource tags.')
param tags object = {}

var vnetName = '${namePrefix}-vnet'
var vmSubnetName = '${namePrefix}-snet-vms'
var bastionSubnetName = 'AzureBastionSubnet'
var nsgName = '${namePrefix}-nsg-vms'
var bastionPublicIpName = '${namePrefix}-pip-bastion'
var bastionName = '${namePrefix}-bastion'

resource vmNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowRdpFromAdminIp'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: adminPublicIpCidr
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
      {
        name: 'AllowSshFromAdminIp'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: adminPublicIpCidr
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: concat([
      {
        name: vmSubnetName
        properties: {
          addressPrefix: vmSubnetAddressPrefix
          networkSecurityGroup: {
            id: vmNsg.id
          }
        }
      }
    ], deployBastionDeveloper ? [
      {
        name: bastionSubnetName
        properties: {
          addressPrefix: '10.60.0.192/26'
        }
      }
    ] : [])
  }
}

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (deployBastionDeveloper) {
  name: bastionPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
  tags: tags
}

resource bastion 'Microsoft.Network/bastionHosts@2024-05-01' = if (deployBastionDeveloper) {
  name: bastionName
  location: location
  tags: tags
  sku: {
    name: 'Developer'
  }
  properties: {
    dnsName: '${bastionName}-${uniqueString(resourceGroup().id)}'
    ipConfigurations: [
      {
        name: 'bastion-ipconfig'
        properties: {
          publicIPAddress: {
            id: bastionPublicIp.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, bastionSubnetName)
          }
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vmSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, vmSubnetName)
output networkSecurityGroupId string = vmNsg.id
output bastionId string = deployBastionDeveloper ? bastion.id : ''
output bastionPortalUrl string = deployBastionDeveloper ? 'https://portal.azure.com/#@/resource${bastion.id}/overview' : ''