# Teardown

Deleting only `rg-aum-demo-eastus2` is incomplete. Dynamic maintenance configuration assignments
are subscription resources, and the periodic-assessment policy creates a managed identity with a
role assignment. The scripts remove those resources before deleting the group.

## Full teardown

PowerShell:

```powershell
./scripts/teardown.ps1
```

Bash:

```bash
./scripts/teardown.sh
```

Both scripts require the resource group name as typed confirmation. For unattended runs:

```powershell
./scripts/teardown.ps1 -Force
```

```bash
FORCE=true ./scripts/teardown.sh
```

If Windows blocks the script with `running scripts is disabled on this system`, run it for a
single process instead:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\teardown.ps1 -Force
```

By default, teardown waits for resource-group deletion and verifies that it no longer exists. Use
`-NoWait` in PowerShell or `NO_WAIT=true` in Bash only when asynchronous deletion is intentional.

## Deletion order

1. Select the requested subscription.
2. Find both current and legacy periodic-assessment policy names at resource-group and subscription
   scope.
3. Read each policy identity and delete every role assignment owned by that identity.
4. Delete the policy assignment.
5. Inspect the known current and legacy subscription-level maintenance assignments, and delete only
   assignments whose filter targets the demo resource group or whose maintenance configuration ID
   belongs to it.
6. Delete the resource group. This also removes maintenance configurations, the VM-level static
   assignment, VMs, disks, NICs, monitoring resources, alerting, and Automation resources.
7. In synchronous mode, verify that the resource group is absent.

The resource checks prevent a similarly named assignment for another resource group from being
deleted.

## Partial teardown: deallocate VMs

To retain the configuration while stopping compute charges:

```powershell
$resourceGroup = 'rg-aum-demo-eastus2'
az vm list -g $resourceGroup --query '[].name' -o tsv |
  ForEach-Object { az vm deallocate -g $resourceGroup -n $_ --no-wait }
```

Deallocated VMs still incur disk, Log Analytics ingestion, and any enabled Defender charges.

## Independent verification

Set the values once:

```powershell
$subscriptionId = 'c69f7b0e-bf5b-4e01-b8c9-5a9fd00dae85'
$resourceGroup = 'rg-aum-demo-eastus2'
$scope = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup"
```

The resource group must be absent:

```powershell
az group exists --name $resourceGroup
# expected: false
```

No demo policy assignment should remain at either relevant scope:

```powershell
az policy assignment list --scope $scope `
  --query "[?starts_with(name, 'aumdemo-periodic-assess')].id" -o tsv
az policy assignment list --scope "/subscriptions/$subscriptionId" `
  --query "[?starts_with(name, 'aumdemo-periodic-assess')].id" -o tsv
# expected: no output
```

No known dynamic assignment should resolve:

```powershell
'dynamic-0','dynamic-1','dynscope-prod-monthly','dynscope-nonprod-weekly' |
  ForEach-Object {
    az resource show --ids "/subscriptions/$subscriptionId/providers/Microsoft.Maintenance/configurationAssignments/$_" `
      --api-version 2023-04-01 --query id -o tsv 2>$null
  }
# expected: no output
```

If a policy identity was recorded before teardown, verify that it owns no roles:

```powershell
az role assignment list --assignee-object-id '<policy-principal-id>' --all --query '[].id' -o tsv
# expected: no output
```

## Recovery after an interrupted teardown

Rerun the same script with `-Force` or `FORCE=true`. Every discovery step tolerates an already
absent target, so teardown is safe to resume. Do not manually delete the policy first: deleting its
managed identity makes the associated role assignment harder to discover.
