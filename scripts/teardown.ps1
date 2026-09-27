[CmdletBinding()]
param(
    [string]$SubscriptionId = 'c69f7b0e-bf5b-4e01-b8c9-5a9fd00dae85',
    [string]$ResourceGroupName = 'rg-aum-demo-eastus2',
    [string]$NamePrefix = 'aumdemo',
    [switch]$Force,
    [switch]$NoWait
)

$ErrorActionPreference = 'Stop'

function Assert-AzSuccess([string]$Operation) {
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI failed while $Operation."
    }
}

# Azure CLI writes to stderr for expected "not found" results. Windows PowerShell converts native
# stderr into a terminating error while ErrorActionPreference is Stop, so probes run through here.
function Invoke-AzProbe([string[]]$Arguments) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & az @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    $standardOutput = @($output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })
    return [pscustomobject]@{
        ExitCode = $exitCode
        Output   = ($standardOutput -join [Environment]::NewLine)
    }
}

az account set --subscription $SubscriptionId
Assert-AzSuccess 'selecting the target subscription'

if (-not $Force) {
    $confirmation = Read-Host "Type '$ResourceGroupName' to delete the demo and its subscription-scoped resources"
    if ($confirmation -cne $ResourceGroupName) {
        throw 'Confirmation did not match; nothing was deleted.'
    }
}

$resourceGroupScope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName"
$subscriptionScope = "/subscriptions/$SubscriptionId"
$policyNames = @(
    "${NamePrefix}-periodic-assessment",
    "${NamePrefix}-periodic-assess"
)

Write-Host 'Discovering demo policy assignments and their identities.' -ForegroundColor Cyan
$policyAssignments = @()
foreach ($scope in @($resourceGroupScope, $subscriptionScope)) {
    $assignmentsJson = az policy assignment list --scope $scope -o json
    Assert-AzSuccess "listing policy assignments at $scope"
    $policyAssignments += @($assignmentsJson | ConvertFrom-Json | Where-Object {
        $_.name -in $policyNames -and $_.id -match "/providers/Microsoft\.Authorization/policyAssignments/[^/]+$"
    })
}
$policyAssignments = @($policyAssignments | Sort-Object id -Unique)

foreach ($assignment in $policyAssignments) {
    $principalId = $assignment.identity.principalId
    if ($principalId) {
        $rolesJson = az role assignment list --assignee-object-id $principalId --all -o json
        Assert-AzSuccess "listing role assignments for policy identity $principalId"
        $roleAssignments = @($rolesJson | ConvertFrom-Json)
        foreach ($roleAssignment in $roleAssignments) {
            Write-Host "Removing policy-created role assignment $($roleAssignment.id)" -ForegroundColor Yellow
            az role assignment delete --ids $roleAssignment.id
            Assert-AzSuccess "deleting role assignment $($roleAssignment.id)"
        }
    }

    Write-Host "Removing policy assignment $($assignment.id)" -ForegroundColor Yellow
    $assignmentScope = $assignment.id -replace '/providers/Microsoft\.Authorization/policyAssignments/[^/]+$', ''
    az policy assignment delete --name $assignment.name --scope $assignmentScope
    Assert-AzSuccess "deleting policy assignment $($assignment.id)"
}

$configurationAssignmentNames = @(
    'dynamic-0',
    'dynamic-1',
    'dynscope-prod-monthly',
    'dynscope-nonprod-weekly'
)

foreach ($assignmentName in $configurationAssignmentNames) {
    $assignmentId = "$subscriptionScope/providers/Microsoft.Maintenance/configurationAssignments/$assignmentName"
    $probe = Invoke-AzProbe @('resource', 'show', '--ids', $assignmentId, '--api-version', '2023-04-01', '-o', 'json')
    if ($probe.ExitCode -ne 0 -or -not $probe.Output) {
        Write-Host "No configuration assignment named $assignmentName; skipping." -ForegroundColor DarkGray
        continue
    }

    $assignment = $probe.Output | ConvertFrom-Json
    $targetsResourceGroup = @($assignment.properties.filter.resourceGroups) -contains $ResourceGroupName
    $usesDemoConfiguration = $assignment.properties.maintenanceConfigurationId -like "$resourceGroupScope/*"
    if ($targetsResourceGroup -or $usesDemoConfiguration) {
        Write-Host "Removing subscription-scoped configuration assignment $assignmentId" -ForegroundColor Yellow
        az resource delete --ids $assignmentId --api-version 2023-04-01
        Assert-AzSuccess "deleting configuration assignment $assignmentId"
    }
}

Write-Host "Deleting resource group $ResourceGroupName." -ForegroundColor Yellow
$deleteArguments = @('group', 'delete', '--name', $ResourceGroupName, '--yes')
if ($NoWait) {
    $deleteArguments += '--no-wait'
}
az @deleteArguments
Assert-AzSuccess "deleting resource group $ResourceGroupName"

if ($NoWait) {
    Write-Host "Deletion requested for $ResourceGroupName; subscription-scoped resources were removed first." -ForegroundColor Green
    exit 0
}

$groupExists = az group exists --name $ResourceGroupName -o tsv
Assert-AzSuccess "verifying deletion of resource group $ResourceGroupName"
if ($groupExists -ne 'false') {
    throw "Resource group $ResourceGroupName still exists after deletion completed."
}

Write-Host 'Teardown verified: the resource group, demo policies, policy identity roles, and dynamic configuration assignments are gone.' -ForegroundColor Green
