<#
.SYNOPSIS
  Pre-flight checks for the Azure Update Manager demo: quota, provider registration, marketplace terms.
.DESCRIPTION
  Read-only checks. Run before deploy.ps1. Requires az CLI logged in to the target tenant/subscription.
#>
[CmdletBinding()]
param(
    [string]$TenantId = '46d3e391-bd8a-44cb-a6f7-10ff4b3405ef',
    [string]$SubscriptionId = 'c69f7b0e-bf5b-4e01-b8c9-5a9fd00dae85',
    [string]$Location = 'eastus2'
)

$ErrorActionPreference = 'Stop'

function Write-Check {
    param([string]$Message, [bool]$Pass)
    $status = if ($Pass) { 'OK' } else { 'ACTION NEEDED' }
    $color = if ($Pass) { 'Green' } else { 'Yellow' }
    Write-Host "[$status] $Message" -ForegroundColor $color
}

Write-Host "=== Azure Update Manager Demo — Preflight Checks ===" -ForegroundColor Cyan

$account = az account show --query "{tenantId:tenantId, subId:id}" -o json | ConvertFrom-Json
Write-Check "Logged in via az login" ($null -ne $account)

if ($account.tenantId -ne $TenantId) {
    Write-Check "Correct tenant ($TenantId)" $false
    Write-Host "  Run: az login --tenant $TenantId" -ForegroundColor Yellow
} else {
    Write-Check "Correct tenant ($TenantId)" $true
}

az account set --subscription $SubscriptionId
Write-Check "Subscription set to $SubscriptionId" $true

# Provider registration
$providers = @('Microsoft.Maintenance', 'Microsoft.HybridCompute', 'Microsoft.PolicyInsights', 'Microsoft.ResourceGraph', 'Microsoft.Compute', 'Microsoft.Network', 'Microsoft.OperationalInsights', 'Microsoft.Automation', 'Microsoft.Insights')
foreach ($p in $providers) {
    $state = az provider show -n $p --query registrationState -o tsv
    $pass = $state -eq 'Registered'
    Write-Check "Provider $p registered" $pass
    if (-not $pass) {
        Write-Host "  Registering $p (may take a few minutes)..." -ForegroundColor Yellow
        az provider register -n $p | Out-Null
    }
}

# Quota check: Standard BSv2/BS family needs >= 16 vCPUs for 8x Standard_B2s
$usage = az vm list-usage --location $Location --query "[?contains(name.value, 'standardBSFamily')]" -o json | ConvertFrom-Json
if ($usage) {
    $limit = $usage[0].limit
    $current = $usage[0].currentValue
    $available = [int]$limit - [int]$current
    Write-Check "Standard BS Family quota >= 16 vCPUs available (current: $available)" ($available -ge 16)
} else {
    Write-Host "  Could not read Standard BS Family quota — verify manually with 'az vm list-usage --location $Location'" -ForegroundColor Yellow
}

# RHEL PAYG marketplace terms
$termsAccepted = az vm image terms show --publisher RedHat --offer RHEL --plan '9-lvm-gen2' --query accepted -o tsv 2>$null
if ($termsAccepted -ne 'true') {
    Write-Check "RHEL 9 PAYG marketplace terms accepted" $false
    Write-Host "  Run: az vm image terms accept --publisher RedHat --offer RHEL --plan 9-lvm-gen2" -ForegroundColor Yellow
} else {
    Write-Check "RHEL 9 PAYG marketplace terms accepted" $true
}

# Verify the built-in periodic assessment policy definition ID used by the policy module
$policyMatch = az policy definition list --query "[?contains(displayName, 'periodic')].{name:name, id:id, displayName:displayName}" -o json | ConvertFrom-Json
if ($policyMatch) {
    Write-Host "Found candidate built-in policy definitions (verify bicep/modules/policy-periodic-assessment.bicep matches):" -ForegroundColor Cyan
    $policyMatch | ForEach-Object { Write-Host "  $($_.displayName): $($_.id)" }
} else {
    Write-Check "Located built-in periodic assessment policy definition" $false
}

Write-Host "=== Preflight complete ===" -ForegroundColor Cyan
