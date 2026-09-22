using '../main.bicep'

param location = 'eastus2'
param resourceGroupName = 'rg-aum-demo-eastus2'
param namePrefix = 'aumdemo'
param tenantId = '46d3e391-bd8a-44cb-a6f7-10ff4b3405ef'
param subscriptionId = 'c69f7b0e-bf5b-4e01-b8c9-5a9fd00dae85'
param owner = readEnvironmentVariable('AUM_OWNER', 'demo-owner')
param adminPublicIpCidr = readEnvironmentVariable('AUM_ADMIN_PUBLIC_IP_CIDR')
param alertEmail = readEnvironmentVariable('AUM_ALERT_EMAIL')
param adminPassword = readEnvironmentVariable('AUM_ADMIN_PASSWORD')
param sshPublicKey = readEnvironmentVariable('AUM_SSH_PUBLIC_KEY', '')
param linuxAuthenticationType = readEnvironmentVariable('AUM_LINUX_AUTHENTICATION_TYPE', 'sshPublicKey')
param deployBastionDeveloper = false
param windowsImageVersion = 'latest'
param ubuntuImageVersion = 'latest'
param rhelImageVersion = 'latest'
param schedules = [
  {
    name: 'Prod-Monthly-Sunday-2AM'
    environment: 'Prod'
    visibility: 'Custom'
    startDateTime: '2026-09-27 02:00'
    duration: '03:00'
    timeZone: 'Eastern Standard Time'
    recurEvery: 'Month Fourth Sunday'
    rebootSetting: 'IfRequired'
    windowsClassifications: [
      'Critical'
      'Security'
    ]
    linuxClassifications: [
      'Critical'
      'Security'
    ]
  }
  {
    name: 'NonProd-Weekly-Friday-10PM'
    environment: 'NonProd'
    visibility: 'Custom'
    startDateTime: '2026-09-25 22:00'
    duration: '04:00'
    timeZone: 'Eastern Standard Time'
    recurEvery: '1Week Friday'
    rebootSetting: 'Always'
    windowsClassifications: [
      'Critical'
      'Security'
      'Other'
    ]
    linuxClassifications: [
      'Critical'
      'Security'
      'Other'
    ]
  }
]
