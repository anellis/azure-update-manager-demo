# Teardown

## Full teardown (everything)

```powershell
./scripts/teardown.ps1
```

Prompts for a typed confirmation of the resource group name, then runs
`az group delete --name rg-aum-demo-eastus2 --yes --no-wait`. Deletion runs in the background —
check progress with:

```powershell
az group show --name rg-aum-demo-eastus2 --query properties.provisioningState -o tsv
```

Skip the confirmation prompt (e.g. in CI) with `./scripts/teardown.ps1 -Force`.

## Partial teardown (stop VMs, keep the environment for tomorrow)

To save cost overnight without losing the deployed configuration:

```powershell
az vm deallocate --resource-group rg-aum-demo-eastus2 --name vm-win22-prod --no-wait
# repeat for each of the 8 VMs, or loop over `az vm list -g rg-aum-demo-eastus2 --query "[].name" -o tsv`
```

Deallocated (stopped) VMs stop incurring compute charges but still incur managed disk storage
cost (a few cents/day total for 8 Standard SSD OS disks).

## Verifying nothing is left behind

```powershell
az resource list --resource-group rg-aum-demo-eastus2 -o table
az group exists --name rg-aum-demo-eastus2
```

`az group exists` should return `false` once deletion completes.
