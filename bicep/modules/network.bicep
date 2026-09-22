// Minimal network for the demo estate: no public IPs, outbound internet via default rules only.
@description('Azure region for all resources.')
param location string

@description('Resource name prefix.')
param namePrefix string

@description('Tags to apply to all resources.')
param tags object = {}

var vnetName = '${namePrefix}-vnet'
var subnetName = '${namePrefix}-snet-vms'
var nsgName = '${namePrefix}-nsg-vms'

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    // No inbound allow rules: access is via az vm run-command / Serial Console only.
    securityRules: [
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

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.60.0.0/24'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.60.0.0/26'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

output subnetId string = vnet.properties.subnets[0].id
output vnetId string = vnet.id
