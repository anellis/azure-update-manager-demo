// Assigns the built-in "Configure periodic checking for missing system updates" initiative
// at resource group scope, with a system-assigned identity + role assignment for DINE remediation.
// NOTE: verify policyDefinitionId with `az policy definition list` (scripts/preflight-checks.ps1
// does this) — built-in GUIDs can change between API/portal releases.
@description('Azure region (used for the policy assignment identity).')
param location string

@description('Resource name prefix.')
param namePrefix string

@description('Built-in policy (initiative) definition ID for periodic assessment. Verify before use.')
param policyDefinitionId string = '/providers/Microsoft.Authorization/policySetDefinitions/59efceea-0c96-497e-a4a1-4eb2290dac15'

@description('Role definition ID required by the DINE effect to configure the assessment extension.')
param roleDefinitionId string = '9980e02c-c2be-4d73-94e8-173b1dc7cf3c' // Virtual Machine Contributor

resource assignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: '${namePrefix}-periodic-assess'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'AUM Demo — Enforce periodic assessment'
    description: 'Enforces periodic checking for missing system updates across the demo resource group.'
    policyDefinitionId: policyDefinitionId
    enforcementMode: 'Default'
  }
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, assignment.id, roleDefinitionId)
  properties: {
    principalId: assignment.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
  }
}

resource remediation 'Microsoft.PolicyInsights/remediations@2021-10-01' = {
  name: '${namePrefix}-periodic-assess-remediation'
  properties: {
    policyAssignmentId: assignment.id
    resourceDiscoveryMode: 'ReEvaluateCompliance'
  }
  dependsOn: [
    roleAssignment
  ]
}

output assignmentId string = assignment.id
