[CmdletBinding()]
param(
  [string]$ResourceGroupName = 'rg-aum-demo-eastus2',
  [string]$WorkspaceName = 'aumdemo-law',
  [string]$Location = 'eastus2',
  [string]$SuccessLinuxVm = 'aumdemo-ubuntu22-nonprod-01',
  [string]$SkippedAssessmentVm = 'aumdemo-ubuntu22-nonprod-03',
  [switch]$AssessAll
)

$ErrorActionPreference = 'Stop'
$az = 'az'
$workspaceId = & $az resource show -g $ResourceGroupName -n $WorkspaceName --resource-type Microsoft.OperationalInsights/workspaces --query id -o tsv
if (-not $workspaceId) { throw "Workspace '$WorkspaceName' was not found." }

$vms = @(& $az vm list -g $ResourceGroupName --query '[].{name:name,os:storageProfile.osDisk.osType}' -o json | ConvertFrom-Json)
if ($vms.Count -eq 1 -and $vms[0] -is [array]) { $vms = @($vms[0]) }
if ($vms.Count -ne 6) { throw "Expected 6 VMs, found $($vms.Count)." }

function Write-Step([string]$Message) { Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "[$(Get-Date -Format 'HH:mm:ss')] OK  $Message" -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host "[$(Get-Date -Format 'HH:mm:ss')] NOTE $Message" -ForegroundColor Yellow }

Write-Step 'Starting Update Manager assessment seeding.'
$assessmentTargets = if ($AssessAll) { @($vms.name) } else { @($vms | Where-Object name -ne $SkippedAssessmentVm | Select-Object -ExpandProperty name) }

$subscriptionId = & $az account show --query id -o tsv
$assessmentJobs = @{}
foreach ($vmName in $assessmentTargets) {
  Write-Step "Submitting on-demand assessment: $vmName"
  $result = & $az vm assess-patches -g $ResourceGroupName -n $vmName --no-wait --output json 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Assessment submission failed for ${vmName}: $result" }
  $assessmentJobs[$vmName] = 'Submitted'
}

if ($AssessAll) {
  Write-Warn "AssessAll was selected; no VM will remain intentionally unassessed."
} else {
  Write-Warn "$SkippedAssessmentVm was intentionally skipped so the demo can show a stale/unknown assessment state."
}

Write-Step 'Waiting for assessment results to surface (up to 20 minutes).'
$deadline = (Get-Date).AddMinutes(20)
while ((Get-Date) -lt $deadline) {
  $pending = @()
  foreach ($vmName in $assessmentTargets) {
    $vmId = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/virtualMachines/$vmName"
    $assessmentUrl = "$vmId/patchAssessmentResults/latest?api-version=2022-03-01"
    $assessment = & $az rest --method get --url $assessmentUrl --output json 2>$null | ConvertFrom-Json
    if (-not $assessment -or -not $assessment.properties) { $pending += $vmName }
  }
  if ($pending.Count -eq 0) { break }
  Write-Host "Assessment results are asynchronous; still waiting on $($pending.Count) VM(s)." -ForegroundColor DarkYellow
  Start-Sleep -Seconds 30
}
if ($pending.Count -gt 0) {
  Write-Warn "Assessment results not yet visible for: $($pending -join ', ')"
} else {
  Write-Ok 'Assessment results surfaced for all submitted VMs.'
}

Write-Step "Installing updates through Update Manager on exactly one Linux VM: $SuccessLinuxVm"
$subscriptionId = & $az account show --query id -o tsv
$vmId = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/virtualMachines/$SuccessLinuxVm"
$installUrl = "$vmId/installPatches?api-version=2022-03-01"
$installBody = @{
  maximumDuration = 'PT2H'
  rebootSetting = 'IfRequired'
  linuxParameters = @{
    classificationsToInclude = @('Critical', 'Security')
  }
} | ConvertTo-Json -Depth 10 -Compress
$installResult = & $az rest --method post --url $installUrl --body $installBody --headers 'Content-Type=application/json' --output json 2>&1
if ($LASTEXITCODE -ne 0) {
  throw "Update Manager installPatches failed for ${SuccessLinuxVm}: $installResult"
}
Write-Ok "Update Manager patch installation submitted for $SuccessLinuxVm."

Write-Step 'Preparing four KQL saved-search files.'
$kqlPath = Join-Path $PSScriptRoot '..\kql'
Get-ChildItem $kqlPath -Filter '*.kql' | ForEach-Object {
  $queryName = [IO.Path]::GetFileNameWithoutExtension($_.Name)
  $queryBody = @{
    properties = @{
      category = 'AUM Demo'
      displayName = $queryName
      query = Get-Content $_.FullName -Raw
      version = 1
    }
  } | ConvertTo-Json -Depth 10
  $savedSearchUrl = "$workspaceId/savedSearches/$queryName?api-version=2020-08-01"
  & $az rest --method put --url $savedSearchUrl --body $queryBody --headers 'Content-Type=application/json' --output none
  if ($LASTEXITCODE -ne 0) { throw "Failed to save KQL query $queryName to workspace." }
  Write-Host "  saved $queryName" -ForegroundColor Green
}
Write-Warn 'The compliance/missing-patch/no-assessment queries are authoritative in Resource Graph, not Log Analytics, unless the legacy Update table is separately populated.'

Write-Host ''
Write-Host '=== Demo readiness checklist ===' -ForegroundColor Cyan
Write-Host "Assessment submissions: $($assessmentTargets.Count) VM(s)"
Write-Host "Intentionally unassessed: $(if ($AssessAll) { 'none' } else { $SkippedAssessmentVm })" -ForegroundColor Yellow
Write-Host "Update install attempted on exactly one Linux VM: $SuccessLinuxVm"
Write-Host 'Expected visible data:' -ForegroundColor Green
Write-Host '  - VM inventory, OS mix, patch modes, schedules, dynamic/static assignments, and policy: live now.'
Write-Host '  - Assessment results and missing patch counts: usually 5-15 minutes; allow up to 30 minutes.'
Write-Host '  - Failed-patch alert history: empty unless a real Update Manager installation fails.'
Write-Host '  - Update Manager History: one Linux installPatches run should appear after the asynchronous operation completes; allow 10-30 minutes.' -ForegroundColor Yellow
Write-Host '  - Log Analytics KQL results: Heartbeat/Update tables may be empty unless those data sources are connected; the four saved searches are created, but Resource Graph remains authoritative for Update Manager data.' -ForegroundColor Yellow
Write-Host '  - Workbook: the current /infra deployment does not include a workbook resource. Portal steps: Azure Portal > Monitor > Workbooks > Templates > Update Manager > Save as a shared workbook, then scope it to rg-aum-demo-eastus2.' -ForegroundColor Yellow
Write-Host '=== End readiness checklist ===' -ForegroundColor Cyan
