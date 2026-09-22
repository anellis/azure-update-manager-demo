[CmdletBinding()]
param(
        [string]$SubscriptionId = 'c69f7b0e-bf5b-4e01-b8c9-5a9fd00dae85',
    [string]$ResourceGroupName = 'rg-aum-demo-eastus2',
        [string]$NamePrefix = 'aumdemo',
        [switch]$Force
)

$ErrorActionPreference = 'Stop'
az account set --subscription $SubscriptionId

$dynamicAssignments = @(az resource list --resource-type Microsoft.Maintenance/configurationAssignments --query "[?contains(name, 'dynamic-')].id" -o tsv)
foreach ($assignmentId in $dynamicAssignments) {
    Write-Host "Removing subscription-scope assignment $assignmentId" -ForegroundColor Yellow
    az resource delete --ids $assignmentId
}

$policyId = az policy assignment show --name "${NamePrefix}-periodic-assessment" --scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName" --query id -o tsv 2>$null
if ($policyId) {
    Write-Host "Removing policy assignment $policyId" -ForegroundColor Yellow
    az policy assignment delete --ids $policyId
}

if ($Force -or $PSCmdlet.ShouldProcess($ResourceGroupName, 'Delete resource group')) {
    az group delete --name $ResourceGroupName --yes --no-wait
    Write-Host "Deletion requested for $ResourceGroupName." -ForegroundColor Green
}
