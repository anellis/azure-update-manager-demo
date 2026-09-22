[CmdletBinding()]
param(
  [string]$ResourceGroupName = 'rg-aum-demo-eastus2',
  [string]$NamePrefix = 'aumdemo',
  [string]$Location = 'eastus2'
)

$ErrorActionPreference = 'Stop'
$results = [System.Collections.Generic.List[object]]::new()
function Add-Check([string]$Check, [bool]$Passed, [string]$Details) {
  $results.Add([pscustomobject]@{ Check = $Check; Status = if ($Passed) { 'PASS' } else { 'FAIL' }; Details = $Details })
}

$vms = @(az vm list --resource-group $ResourceGroupName -o json | ConvertFrom-Json)
foreach ($vm in $vms) {
  $power = az vm get-instance-view -g $ResourceGroupName -n $vm.name --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus | [0]" -o tsv
  Add-Check "VM running: $($vm.name)" ($power -eq 'VM running') $power

  $extensions = @(az vm extension list -g $ResourceGroupName --vm-name $vm.name -o json | ConvertFrom-Json)
  $failed = @($extensions | Where-Object { $_.provisioningState -ne 'Succeeded' })
  Add-Check "Extensions succeeded: $($vm.name)" ($failed.Count -eq 0 -and $extensions.Count -gt 0) ("$($extensions.Count) extension(s); failed=$($failed.Count)")

  $assessment = az vm show -g $ResourceGroupName -n $vm.name --query "coalesce(properties.osProfile.windowsConfiguration.patchSettings.assessmentMode, properties.osProfile.linuxConfiguration.patchSettings.assessmentMode)" -o tsv
  Add-Check "Assessment mode present: $($vm.name)" ($assessment -in @('AutomaticByPlatform','ImageDefault')) $assessment
}

$maintenance = @(az resource list -g $ResourceGroupName --resource-type Microsoft.Maintenance/maintenanceConfigurations -o json | ConvertFrom-Json)
Add-Check 'Maintenance configurations present' ($maintenance.Count -ge 2) ("$($maintenance.Count) found")

$staticAssignments = @(az resource list -g $ResourceGroupName --resource-type Microsoft.Maintenance/configurationAssignments -o json | ConvertFrom-Json)
Add-Check 'Resource-group assignments present' ($staticAssignments.Count -ge 1) ("$($staticAssignments.Count) found")

$subscriptionAssignments = @(az resource list --resource-type Microsoft.Maintenance/configurationAssignments --query "[?contains(name, 'dynamic-')]" -o json | ConvertFrom-Json)
Add-Check 'Dynamic assignments resolved' ($subscriptionAssignments.Count -ge 2) ("$($subscriptionAssignments.Count) found")

$policy = az policy assignment show --name "${NamePrefix}-periodic-assessment" --scope "/subscriptions/$((az account show --query id -o tsv))/resourceGroups/$ResourceGroupName" -o json 2>$null
Add-Check 'Periodic assessment policy present' ($LASTEXITCODE -eq 0 -and $policy) 'Policy assignment queried'

$results | Format-Table -AutoSize
if (@($results | Where-Object Status -eq 'FAIL').Count -gt 0) { exit 1 }
Write-Host 'All validation checks passed.' -ForegroundColor Green
