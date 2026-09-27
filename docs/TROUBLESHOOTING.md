# Troubleshooting

Start by confirming that Azure CLI is pointed at the subscription used by the parameter file:

```powershell
az account show --query '{subscription:id, tenant:tenantId, user:user.name}' -o yaml
az deployment sub list --query "[?starts_with(name, 'aumdemo-')].{name:name,state:properties.provisioningState,timestamp:properties.timestamp}" -o table
```

For a failed parent deployment, inspect the failed nested operation rather than immediately
redeploying:

```powershell
az deployment operation sub list --name '<deployment-name>' `
  --query "[?properties.provisioningState=='Failed'].{resource:properties.targetResource.resourceName,message:properties.statusMessage.error.message}" `
  -o table
```

## VM extension provisioning fails

**Symptoms**

- `AzureMonitorWindowsAgent`, `AzureMonitorLinuxAgent`, or a policy-created assessment extension
  remains in `Creating`, `Transitioning`, or `Failed`.
- `scripts/validate.ps1` reports a failed extension.
- The VM exists but monitoring or Update Manager assessment never converges.

**Diagnose**

```powershell
$rg = 'rg-aum-demo-eastus2'
$vm = '<vm-name>'
az vm extension list -g $rg --vm-name $vm `
  --query "[].{name:name,state:provisioningState,message:instanceView.statuses[-1].message}" -o table
az vm get-instance-view -g $rg -n $vm --query instanceView.vmAgent -o yaml
```

**Fix**

1. Ensure the VM is running and has outbound HTTPS access to Azure platform endpoints. A
   deallocated VM cannot finish extension work.
2. Confirm `Microsoft.Compute`, `Microsoft.Insights`, and `Microsoft.GuestConfiguration` are
   registered:

   ```powershell
   'Microsoft.Compute','Microsoft.Insights','Microsoft.GuestConfiguration' |
     ForEach-Object { az provider register --namespace $_ --wait }
   ```

3. Retry the specific extension without deleting the VM:

   ```powershell
   az vm extension set -g $rg --vm-name $vm `
     --publisher Microsoft.Azure.Monitor `
     --name AzureMonitorWindowsAgent `
     --enable-auto-upgrade true
   ```

   Use `AzureMonitorLinuxAgent` for Linux.

4. If the VM agent is unavailable, use **Help > Redeploy + reapply** in the VM blade or:

   ```powershell
   az vm reapply -g $rg -n $vm
   ```

Do not repeatedly delete and recreate policy extensions while remediation is active; the policy
will race the manual operation.

## Assessment is stuck or never completes

**Symptoms**

- `az vm assess-patches --no-wait` succeeds, but no result appears.
- Update Manager shows `Not assessed`, `Unknown`, or an old timestamp for more than 30 minutes.

**Diagnose**

```powershell
$vmId = az vm show -g rg-aum-demo-eastus2 -n '<vm-name>' --query id -o tsv
az rest --method get `
  --url "$vmId/patchAssessmentResults/latest?api-version=2022-03-01" -o json
```

Check the configured mode:

```powershell
az vm show -g rg-aum-demo-eastus2 -n '<vm-name>' `
  --query "{windows:osProfile.windowsConfiguration.patchSettings,linux:osProfile.linuxConfiguration.patchSettings}" `
  -o yaml
```

**Fix**

1. Start the VM; assessment does not run while it is deallocated.
2. Verify `assessmentMode` is `AutomaticByPlatform`. The
   `aumdemo-ubuntu22-nonprod-03` VM intentionally uses `ImageDefault` and is expected to remain
   stale unless `scripts/seed-demo.ps1 -AssessAll` is used.
3. Submit one new assessment and wait instead of submitting repeated jobs:

   ```powershell
   az vm assess-patches -g rg-aum-demo-eastus2 -n '<vm-name>' --no-wait
   ```

4. Confirm the VM agent and extensions are healthy using the previous section.
5. Allow 10–30 minutes for Resource Graph and the portal to reflect the result. Refreshing the
   blade does not accelerate the platform operation.

## A VM does not appear in Update Manager

**Likely causes**

- The wrong subscription, resource group, region, or portal filter is selected.
- The VM was just created and inventory discovery has not completed.
- The VM agent is unhealthy, the operating system is unsupported, or required providers are not
  registered.
- The VM is filtered out by the current Update Manager blade query.

**Fix**

```powershell
az vm show -g rg-aum-demo-eastus2 -n '<vm-name>' --query '{id:id,location:location,state:provisioningState}' -o yaml
az provider show --namespace Microsoft.Maintenance --query registrationState -o tsv
az provider show --namespace Microsoft.Compute --query registrationState -o tsv
```

Register any missing provider, start the VM, verify the VM agent, then trigger an on-demand
assessment. In the portal, clear all Update Manager filters and select the same subscription as
`az account show`. New VMs commonly take several minutes to appear even when deployment has
succeeded.

## Patch mode conflicts with a maintenance schedule

**Symptoms**

- A static or dynamic assignment fails with an eligibility or validation error.
- Customer Managed Schedules does not apply to a VM.
- Deployment rejects `automaticByPlatformSettings`.

**Rules used by this repository**

- Customer Managed Schedules require `patchMode: AutomaticByPlatform`.
- `bypassPlatformSafetyChecksOnUserSchedule: true` marks the customer-managed examples.
- `automaticByPlatformSettings` must not be sent when patch mode is `Manual` or `ImageDefault`.
- Periodic assessment is independent from patch installation mode.

Inspect the active settings:

```powershell
az vm show -g rg-aum-demo-eastus2 -n '<vm-name>' `
  --query "{windows:osProfile.windowsConfiguration.patchSettings,linux:osProfile.linuxConfiguration.patchSettings}" `
  -o json
```

For a schedule target, update the OS-specific patch configuration to
`AutomaticByPlatform`, then reapply the maintenance assignment. Do not attach the intentionally
assessment-off VM to the static schedule; the repository uses
`aumdemo-ubuntu22-nonprod-01`, which is eligible.

## Quota or regional capacity failure

Six `Standard_B2s` VMs require 12 BS-family vCPUs in `eastus2`.

```powershell
az vm list-usage --location eastus2 `
  --query "[?contains(localName, 'BS')].{name:localName,current:currentValue,limit:limit}" -o table
```

If the limit is too low, request a quota increase in **Subscriptions > Usage + quotas**, reduce the
VM count, or choose a size family with sufficient quota and update `vmSize`. If quota is available
but Azure reports allocation failure, retry later or deploy to another supported region; changing
regions also requires reviewing schedule timezone, image availability, and allowed management
CIDR.

## Policy remediation remains non-compliant

The built-in deploy-if-not-exists policy can take 10–30 minutes to evaluate and remediate.

```powershell
$scope = '/subscriptions/<subscription-id>/resourceGroups/rg-aum-demo-eastus2'
az policy assignment show --name aumdemo-periodic-assessment --scope $scope `
  --query '{principalId:identity.principalId,state:properties.enforcementMode}' -o yaml
az role assignment list --scope $scope `
  --query "[?principalId=='<principal-id>'].{role:roleDefinitionName,scope:scope}" -o table
```

The identity must have `Virtual Machine Contributor` at the demo resource group. If the role is
missing, redeploy `infra/modules/policy.bicep`, then create a new remediation task. Treat
`Non-compliant` as "remediation in progress" until the policy state timestamp advances.

## Deployment fails on a marketplace image

The canonical six-VM deployment uses Ubuntu and Windows images that do not require a paid RHEL
plan. The legacy `bicep/` reference includes RHEL. For that template, accept terms before deployment:

```powershell
az vm image terms accept --publisher RedHat --offer RHEL --plan 9-lvm-gen2
```

If the subscription cannot purchase marketplace offers, use the canonical `infra/` deployment.

## Reporting data is empty

Update Manager assessment and installation data is stored in Azure Resource Graph, not
automatically in Log Analytics. The KQL files are saved for demonstration, but `Update` or
`Heartbeat` can be empty unless the corresponding data collection is configured. Use the Update
Manager portal or Resource Graph for authoritative patch status.

Run `scripts/seed-demo.ps1` while the VMs are running and allow 10–30 minutes. The current `infra/`
deployment does not create a shared workbook; save the first-party Update Manager workbook from the
portal if a persistent dashboard is required.

## First deployment record

The first deployment on September 21–22, 2026 exposed and fixed these issues:

- Windows guest names exceeded the 15-character limit.
- Manual Linux patch mode incorrectly received `automaticByPlatformSettings`.
- Dynamic assignment resources required `global` location.
- The alert operation name needed `Microsoft.Maintenance/applyUpdates/write`.
- The DCR used unsupported `kind` and Windows event stream values.
- Static assignment needed an explicit location and an eligible target VM.
- The periodic-assessment resource is a `policyDefinitions` resource, not a policy set.
- PowerShell needed explicit Azure CLI exit-code checks and array flattening.

The core resources and six VMs were available in about 17 minutes. In-place diagnosis and final
policy remediation extended that first run to 64 minutes. These corrections are now represented in
the source and validation scripts.

## Emergency demo fallback

1. Do not redeploy the entire environment immediately before a presentation.
2. Use the healthy VMs and schedules that remain, and disclose any missing live data.
3. Use previously captured screenshots only when clearly labeled with their capture time.
4. Use the architecture diagram to explain a temporarily unavailable view.

For complete cleanup, see [TEARDOWN.md](TEARDOWN.md).
