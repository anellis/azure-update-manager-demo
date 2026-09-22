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
