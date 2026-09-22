<#
.SYNOPSIS
  Deploys the Azure Update Manager demo environment end-to-end.
.DESCRIPTION
  Prompts for VM credentials and alert email (never stored in the repo), deploys the Bicep
  orchestrator at subscription scope, then publishes the pre/post patch stub runbook content.
#>
[CmdletBinding()]
param(
    [string]$SubscriptionId = 'c69f7b0e-bf5b-4e01-b8c9-5a9fd00dae85',
    [string]$Location = 'eastus2',
    [string]$ResourceGroupName = 'rg-aum-demo-eastus2',
    [string]$NamePrefix = 'aumdemo'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

az account set --subscription $SubscriptionId

if (-not $env:AUM_ADMIN_USERNAME) { $env:AUM_ADMIN_USERNAME = 'aumdemoadmin' }
if (-not $env:AUM_ADMIN_PASSWORD) {
    $securePwd = Read-Host -Prompt 'VM local admin password (Windows + Linux fallback)' -AsSecureString
    $env:AUM_ADMIN_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePwd))
}
if (-not $env:AUM_SSH_PUBLIC_KEY) {
    $defaultKeyPath = Join-Path $HOME '.ssh\id_rsa.pub'
    if (Test-Path $defaultKeyPath) {
        $env:AUM_SSH_PUBLIC_KEY = Get-Content $defaultKeyPath -Raw
    } else {
        Write-Host "No SSH public key found at $defaultKeyPath — generate one with 'ssh-keygen' or set `$env:AUM_SSH_PUBLIC_KEY." -ForegroundColor Yellow
    }
}
if (-not $env:AUM_ALERT_EMAIL) {
    $env:AUM_ALERT_EMAIL = Read-Host -Prompt 'Email address for the failed-patch-install alert'
}

Write-Host "Deploying resource group + all modules (this can take 15-25 minutes)..." -ForegroundColor Cyan
az deployment sub create `
    --location $Location `
    --template-file (Join-Path $repoRoot 'bicep/main.bicep') `
    --parameters (Join-Path $repoRoot 'bicep/main.bicepparam') `
    --parameters location=$Location resourceGroupName=$ResourceGroupName namePrefix=$NamePrefix

Write-Host "Publishing pre/post patch stub runbook content..." -ForegroundColor Cyan
$automationAccountName = az deployment sub show --name main --query "properties.outputs.automationAccountName.value" -o tsv 2>$null
if (-not $automationAccountName) { $automationAccountName = "$NamePrefix-aa" }

az automation runbook replace-content `
    --resource-group $ResourceGroupName `
    --automation-account-name $automationAccountName `
    --name 'PrePostPatch-Stub' `
    --content "@$(Join-Path $repoRoot 'automation/PrePostPatch-Stub.ps1')"

az automation runbook publish `
    --resource-group $ResourceGroupName `
    --automation-account-name $automationAccountName `
    --name 'PrePostPatch-Stub'

Write-Host "Deployment complete. Next: run scripts/seed-noncompliance.ps1 the night before the demo." -ForegroundColor Green
