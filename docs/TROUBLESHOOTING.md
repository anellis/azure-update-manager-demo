# Troubleshooting

## Deployment fails on RHEL VM creation
Accept marketplace terms first:
```powershell
az vm image terms accept --publisher RedHat --offer RHEL --plan 9-lvm-gen2
```

## Deployment fails with quota error
Check and request a bump:
```powershell
az vm list-usage --location eastus2 -o table
```
8x `Standard_B2s` needs 16 vCPUs of `standardBSFamily` quota.

## Compliance data not showing in the workbook
- Assessment is asynchronous; allow 10-15 minutes after `scripts/seed-noncompliance.ps1`.
- Verify the exact Resource Graph table/column names in Resource Graph Explorer — these have
  changed across Update Manager API versions. Update `bicep/modules/resourcegraph-queries.bicep`
  and `bicep/modules/workbook.bicep` if the schema has shifted.
- Confirm the VM actually has `assessmentMode: AutomaticByPlatform` (the two NonProd VMs on
  `ImageDefault` are intentionally excluded).

## Policy assignment shows "Non-compliant" and remediation hasn't converged
This is expected — DINE remediation can take 10+ minutes. Narrate it as "remediation in progress",
never as already-enforced, if it hasn't converged by demo time.

## Something breaks 20 minutes before the demo
1. Don't attempt a live redeploy of the broken piece — narrate around it with the remaining
   working resources.
2. Fall back to pre-captured workbook screenshots for the reporting section, labeled explicitly
   as "captured earlier" — never presented as live data.
3. If a VM is missing entirely, skip that OS in the walkthrough and cover it verbally using the
   architecture diagram in [PLAN.md](../PLAN.md).

## Full teardown
See [TEARDOWN.md](TEARDOWN.md).

## Deployment run log

### 2026-09-21 — first deployment attempt

The what-if completed, but the initial deployment failed in several independent resources:

- Windows VM guest names exceeded the 15-character `computerName` limit. Fixed by deriving a
   hyphen-free, 15-character guest name while preserving the Azure VM resource name.
- The manual Ubuntu VM received `automaticByPlatformSettings` even though its patch mode was
   `ImageDefault`. Fixed by emitting that property only for `AutomaticByPlatform` VMs.
- Subscription-scope dynamic maintenance assignments used `eastus2` as their resource location.
   Azure rejected it because these assignments require `global`; the module now uses `global`.
- The failed-patch alert used `Microsoft.Maintenance/applyUpdates/action`. Azure's supported
   operation is `Microsoft.Maintenance/applyUpdates/write`; the alert now uses the supported name.
- `scripts/deploy.ps1` printed success after a failed Azure CLI command because it did not check
   `$LASTEXITCODE`. It now stops immediately after failed provider registration, what-if, or deploy.

The RHEL marketplace image was also replaced before this deployment attempt because the target
internal/sandbox subscription cannot purchase paid marketplace offers. The six-VM demo currently
uses three Ubuntu 22.04, two Windows Server 2022, and one Windows Server 2019 VM.
