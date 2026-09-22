[CmdletBinding()]
param(
    [string]$SubscriptionId = 'c69f7b0e-bf5b-4e01-b8c9-5a9fd00dae85',
        [string]$TenantId = '46d3e391-bd8a-44cb-a6f7-10ff4b3405ef',
        [string]$Location = 'eastus2',
        [string]$ParameterFile = "$PSScriptRoot\..\infra\parameters\demo.bicepparam"
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$start = Get-Date

function Write-Step([string]$Message) { Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "[$(Get-Date -Format 'HH:mm:ss')] OK  $Message" -ForegroundColor Green }

Write-Step 'Checking Azure CLI login.'
$account = az account show --query '{tenantId:tenantId,id:id}' -o json 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "Run: az login --tenant $TenantId" -ForegroundColor Yellow
    throw 'Azure CLI is not authenticated.'
}
if ($account.tenantId -ne $TenantId) { throw "Logged-in tenant '$($account.tenantId)' does not match '$TenantId'." }
az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) { throw 'Failed to select the target subscription.' }
Write-Ok "Using tenant $TenantId and subscription $SubscriptionId."

Write-Step 'Registering required resource providers.'
@('Microsoft.Compute','Microsoft.Network','Microsoft.Insights','Microsoft.Maintenance','Microsoft.PolicyInsights','Microsoft.Automation','Microsoft.OperationalInsights') | ForEach-Object {
    az provider register --namespace $_ --wait | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Failed to register provider $_." }
    Write-Ok "Registered $_"
}

Write-Step 'Checking required deployment environment variables.'
@('AUM_ADMIN_PUBLIC_IP_CIDR','AUM_ALERT_EMAIL','AUM_ADMIN_PASSWORD','AUM_SSH_PUBLIC_KEY') | ForEach-Object {
    if (-not [Environment]::GetEnvironmentVariable($_)) { throw "Set environment variable $_ before deploying. No secret is read from the repository." }
}

Write-Step "Running subscription what-if from $ParameterFile."
az deployment sub what-if --location $Location --parameters $ParameterFile --template-file (Join-Path $repoRoot 'infra\main.bicep')
if ($LASTEXITCODE -ne 0) { throw 'What-if failed; deployment was not started.' }
Write-Ok 'What-if completed.'

Write-Step 'Starting subscription deployment.'
az deployment sub create --name "aumdemo-$(Get-Date -Format 'yyyyMMddHHmmss')" --location $Location --parameters $ParameterFile --template-file (Join-Path $repoRoot 'infra\main.bicep')
if ($LASTEXITCODE -ne 0) { throw 'Deployment failed. Query deployment operations before retrying.' }
Write-Ok 'Deployment completed.'

$elapsed = (Get-Date) - $start
Write-Host ("Total elapsed: {0:hh\:mm\:ss}" -f $elapsed) -ForegroundColor Green
Write-Host 'Run scripts/validate.ps1 next.' -ForegroundColor Green
