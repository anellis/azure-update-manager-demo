using 'main.bicep'

// Non-secret values — safe to commit and customize.
param location = 'eastus2'
param resourceGroupName = 'rg-aum-demo-eastus2'
param namePrefix = 'aumdemo'
param tags = {
  Project: 'aum-demo'
  Owner: 'change-me'
  CostCenter: 'demo'
}
param vmSize = 'Standard_B2s'
param linuxAuthenticationType = 'sshPublicKey'

// Pin these to a build 1-2 releases behind current so pending updates exist for the demo.
// Look up exact values with: az vm image list --publisher <pub> --offer <offer> --sku <sku> --all -o table
param windowsImageVersion = 'latest'
param ubuntuImageVersion = 'latest'
param rhelImageVersion = 'latest'

// Secrets and per-run values: never hardcode. Populate via environment variables before deploying,
// e.g. (PowerShell): $env:AUM_ADMIN_PASSWORD = (Read-Host -AsSecureString "Admin password" | ConvertFrom-SecureString -AsPlainText)
// or source from Azure Key Vault with az keyvault secret show.
param adminUsername = readEnvironmentVariable('AUM_ADMIN_USERNAME', 'aumdemoadmin')
param adminPassword = readEnvironmentVariable('AUM_ADMIN_PASSWORD')
param sshPublicKey = readEnvironmentVariable('AUM_SSH_PUBLIC_KEY', '')
param alertEmail = readEnvironmentVariable('AUM_ALERT_EMAIL')
