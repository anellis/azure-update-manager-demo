# Azure Update Manager Demo

A reproducible Bicep deployment for demonstrating Azure Update Manager with mixed operating
systems, patch orchestration modes, scheduled maintenance, dynamic and static scope assignments,
policy-enforced assessment, alerting, and operational telemetry.

> **Demo scope:** This is a live-demo/proof-of-concept environment, not a production reference
> architecture. It intentionally omits HA, backup, private endpoints, centralized egress, and
> workload-aware patch validation. It is not affiliated with or built for a specific customer.
> Review [docs/real-vs-simulated.md](docs/real-vs-simulated.md) before presenting it.

## What gets deployed

- Six `Standard_B2s` VMs: three Windows Server and three Ubuntu 22.04
- Customer Managed Schedule, Azure-orchestrated, manual, and assessment-off examples
- Monthly Prod and weekly NonProd maintenance configurations
- Two subscription-level dynamic assignments based on the `Environment` tag
- One VM-level static assignment for comparison
- Built-in periodic-assessment policy, managed identity, remediation, and scoped role assignment
- VNet, subnet, NSG, Log Analytics workspace, DCR, Azure Monitor Agents
- Activity Log alert, email action group, Automation Account, and demonstration runbook

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the diagram and design rationale.

## Screenshots

The following slots identify the real portal captures to add after a deployment. They are
intentionally not populated with fabricated UI:

| Screenshot slot | Capture after deployment |
|---|---|
| `docs/images/01-update-manager-machines.png` | Azure Update Manager **Machines** blade showing all six VMs and assessment status |
| `docs/images/02-maintenance-configurations.png` | **Maintenance configurations** showing the Prod and NonProd schedules |
| `docs/images/03-dynamic-scopes.png` | Dynamic scope details showing the `Environment` tag filters |
| `docs/images/04-update-history.png` | Update Manager **History** after `scripts/seed-demo.ps1` completes |
| `docs/images/05-policy-compliance.png` | Policy compliance for the periodic-assessment assignment |

Capture these from the reproducer's own subscription so resource names, timestamps, status, and
cost reflect the run being demonstrated.

## Prerequisites

- Azure CLI 2.60 or later with Bicep (`az bicep install`)
- PowerShell 7+ or Bash
- Owner, or Contributor plus User Access Administrator, on the target subscription
- At least 12 available `standardBSFamily` vCPUs in `eastus2`
- An Azure account authenticated to the tenant and subscription configured in
  `infra/parameters/demo.bicepparam`

## Cold deployment

PowerShell prompts for missing non-secret and secret inputs:

```powershell
az login --tenant 46d3e391-bd8a-44cb-a6f7-10ff4b3405ef
az account set --subscription c69f7b0e-bf5b-4e01-b8c9-5a9fd00dae85
./scripts/preflight-checks.ps1
./scripts/deploy.ps1
./scripts/validate.ps1
./scripts/seed-demo.ps1
```

For Bash, set the required inputs first:

```bash
export AUM_ADMIN_PUBLIC_IP_CIDR='203.0.113.10/32'
export AUM_ALERT_EMAIL='operator@example.com'
export AUM_ADMIN_PASSWORD='<strong-temporary-password>'
export AUM_OWNER='<owner-tag>'
./scripts/deploy.sh
pwsh ./scripts/validate.ps1
pwsh ./scripts/seed-demo.ps1
```

To use another subscription, tenant, region, or resource group, update
`infra/parameters/demo.bicepparam` and pass matching script parameters. Secrets are read from
environment variables and are never committed.

## Observed deployment time

The first cold run began at **2026-09-21 22:35 EDT**. The core network, six VMs, maintenance
configurations, alert, and Automation resources were provisioned in approximately **17 minutes**.
The first end-to-end run took **64 minutes** through the final successful policy remediation
because several template/API mismatches were diagnosed and repaired in place. Those fixes are now
in the repository. For a clean run, budget **25–35 minutes**, including asynchronous extension and
policy convergence, then another **10–30 minutes** for assessment/history data to appear.

## Observed cost

Azure Cost Management reported **$8.03 USD actual cost** for
`rg-aum-demo-eastus2` from **2026-09-22 through 2026-09-27**:

- Deployment/running day: **$4.61**
- Subsequent mostly deallocated days: approximately **$0.74/day**
- Partial day on September 27: **$0.38**

The observed total includes compute, managed disks, Log Analytics, bandwidth, and enabled Defender
meter records associated with the resource group. Prices and subscription benefits vary. The VMs
are currently deallocated; disks, monitoring, and Defender can still accrue charges. Delete the
environment when finished rather than relying only on deallocation.

## Validate all Bicep

```powershell
$env:AUM_ADMIN_PUBLIC_IP_CIDR = '203.0.113.10/32'
$env:AUM_ALERT_EMAIL = 'ci@example.invalid'
$env:AUM_ADMIN_PASSWORD = 'Validation-Only-Password-123!'
Get-ChildItem -Recurse -Filter *.bicep |
  ForEach-Object { az bicep build --file $_.FullName --stdout | Out-Null }
Get-ChildItem -Recurse -Filter *.bicepparam |
  ForEach-Object { az bicep build-params --file $_.FullName --stdout | Out-Null }
```

CI builds every source and parameter file in both `infra/` and `bicep/`.

## Teardown

```powershell
./scripts/teardown.ps1
```

Teardown removes subscription-level configuration assignments, policy-created role assignments,
policy assignments, and then the resource group. It waits and verifies deletion by default. See
[docs/TEARDOWN.md](docs/TEARDOWN.md) before running unattended.

## Repository layout

- `infra/` - canonical deployed Bicep entry point and modules
- `bicep/` - expanded reference implementation, kept compiler-clean
- `scripts/` - preflight, deployment, validation, seeding, and teardown
- `kql/` - saved query sources used by the seeding script
- `automation/` - pre/post patch demonstration runbook
- `docs/` - architecture, demo script, troubleshooting, teardown, and scope disclosures

## More information

- [Architecture and decisions](docs/ARCHITECTURE.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Teardown and verification](docs/TEARDOWN.md)
- [Demo script](docs/DEMO-SCRIPT.md)
- [Real versus simulated features](docs/real-vs-simulated.md)
- [Contributing](CONTRIBUTING.md)
