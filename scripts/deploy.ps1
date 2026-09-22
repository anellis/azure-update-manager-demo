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

function Set-DeploymentInputs {
    if (-not $env:AUM_ADMIN_PUBLIC_IP_CIDR -or $env:AUM_ADMIN_PUBLIC_IP_CIDR -eq '203.0.113.10/32') {
        $ip = Read-Host 'Public IPv4 address allowed for RDP/SSH (for example 73.207.157.214)'
        if ($ip -notmatch '^\d{1,3}(\.\d{1,3}){3}(/32)?$') { throw 'Enter a valid IPv4 address or IPv4 /32 CIDR.' }
        $env:AUM_ADMIN_PUBLIC_IP_CIDR = if ($ip.EndsWith('/32')) { $ip } else { "$ip/32" }
    }

    if (-not $env:AUM_ALERT_EMAIL -or $env:AUM_ALERT_EMAIL -eq 'demo@example.invalid') {
        $env:AUM_ALERT_EMAIL = Read-Host 'Alert email address'
        if ($env:AUM_ALERT_EMAIL -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') { throw 'Enter a valid alert email address.' }
    }

    if (-not $env:AUM_OWNER -or $env:AUM_OWNER -eq 'demo-owner') {
        $env:AUM_OWNER = Read-Host 'Owner tag value'
    }

    if (-not $env:AUM_LINUX_AUTHENTICATION_TYPE) {
        $env:AUM_LINUX_AUTHENTICATION_TYPE = 'password'
    }

    if (-not $env:AUM_ADMIN_PASSWORD -or $env:AUM_ADMIN_PASSWORD -eq 'TemporaryOnly-NotStored-123!') {
        $securePassword = Read-Host 'VM administrator password (12+ characters)' -AsSecureString
        $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        try {
            $env:AUM_ADMIN_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        }
        finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
        }
    }

    if ($env:AUM_LINUX_AUTHENTICATION_TYPE -eq 'sshPublicKey' -and -not $env:AUM_SSH_PUBLIC_KEY) {
        $keyPath = Read-Host 'SSH public key path'
        if (-not (Test-Path $keyPath)) { throw "SSH public key file not found: $keyPath" }
        $env:AUM_SSH_PUBLIC_KEY = (Get-Content $keyPath -Raw).Trim()
    }
}

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
Set-DeploymentInputs
Write-Ok 'Deployment inputs are ready; the password remains process-local and is never written to disk.'

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
