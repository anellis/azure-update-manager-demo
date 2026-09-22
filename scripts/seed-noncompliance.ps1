<#
.SYNOPSIS
  Seeds visible non-compliance/assessment contrast for the demo. Run the night before, not day-of —
  assessment jobs are asynchronous and can take 10-15 minutes to land.
.DESCRIPTION
  Triggers an immediate patch assessment on the four VMs configured with AutomaticByPlatform
  assessment (the "Prod" + Azure-orchestrated ones), and deliberately leaves vm-win19-nonprod and
  vm-rhel9-nonprod untouched (assessmentMode = ImageDefault) so they show stale/unknown compliance —
  a real, not fabricated, contrast.
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'rg-aum-demo-eastus2'
)

$ErrorActionPreference = 'Continue'

$vmsToAssessNow = @(
    'vm-win22-prod',
    'vm-win22-nonprod',
    'vm-win19-prod',
    'vm-ubuntu-prod',
    'vm-ubuntu-nonprod',
    'vm-rhel9-prod'
)

foreach ($vm in $vmsToAssessNow) {
    Write-Host "Triggering patch assessment on $vm ..." -ForegroundColor Cyan
    az vm assess-patches --resource-group $ResourceGroupName --name $vm --no-wait
}

Write-Host ""
Write-Host "Deliberately NOT assessing vm-win19-nonprod / vm-rhel9-nonprod (assessmentMode=ImageDefault)." -ForegroundColor Yellow
Write-Host "These will show 'Unknown'/stale compliance in the workbook — a legitimate contrast to narrate." -ForegroundColor Yellow
Write-Host ""
Write-Host "Assessment jobs are async; allow 10-15 minutes before checking the workbook/Resource Graph." -ForegroundColor Cyan
