@description('Azure region for the policy assignment identity.')
param location string

@description('Policy assignment name prefix.')
param namePrefix string

@description('Built-in initiative ID that configures periodic checking for missing system updates on Azure VMs.')
param policyDefinitionId string = '/providers/Microsoft.Authorization/policySetDefinitions/59efceea-0c96-497e-a4a1-4eb2290dac15'

@description('Role definition IDs granted to the policy assignment identity for remediation.')
param roleDefinitionIds array = [
  '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
]

@description('Policy assignment display name.')
param displayName string = 'Configure periodic checking for missing system updates'

resource assignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: '${namePrefix}-periodic-assessment'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: displayName
    description: 'Configures periodic assessment of missing system updates on Azure VMs.'
    policyDefinitionId: policyDefinitionId
    enforcementMode: 'Default'
  }
}

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for roleDefinitionId in roleDefinitionIds: {
  name: guid(assignment.id, roleDefinitionId)
  properties: {
    principalId: assignment.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
  }
}]

resource remediation 'Microsoft.PolicyInsights/remediations@2021-10-01' = {
  name: '${namePrefix}-periodic-assessment-remediation'
  properties: {
    policyAssignmentId: assignment.id
    resourceDiscoveryMode: 'ReEvaluateCompliance'
  }
  dependsOn: [
    roleAssignments
  ]
}

output assignmentId string = assignment.id
output assignmentPrincipalId string = assignment.identity.principalId
output assignmentPortalUrl string = 'https://portal.azure.com/#@/resource${assignment.id}/overview'