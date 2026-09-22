<#
.SYNOPSIS
  Deletes the entire demo resource group. One command, fully reversible only via redeploy.
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'rg-aum-demo-eastus2',
    [switch]$Force
)

if (-not $Force) {
    $confirmation = Read-Host "This will permanently delete resource group '$ResourceGroupName' and everything in it. Type the resource group name to confirm"
    if ($confirmation -ne $ResourceGroupName) {
        Write-Host "Confirmation did not match — aborting." -ForegroundColor Red
        exit 1
    }
}

az group delete --name $ResourceGroupName --yes --no-wait
Write-Host "Delete requested for '$ResourceGroupName' (running in background — check with 'az group show')." -ForegroundColor Green
