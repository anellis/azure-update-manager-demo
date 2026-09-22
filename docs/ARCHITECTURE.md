# Architecture

Full rationale, resource inventory, module decomposition, and deployment sequencing live in
[PLAN.md](../PLAN.md). This page is a quick-reference summary.

## Diagram

See the architecture diagram in [README.md](../README.md#architecture) (same diagram, kept in
sync in both places).

## Scopes

| Deployment scope | Modules |
|---|---|
| Subscription | resource group creation, dynamic scope assignment, Resource Graph saved queries |
| Resource group | network, Log Analytics, Automation account, all 8 VMs, maintenance configurations, static scope assignment, policy assignment, workbook, alerting |

## Dependency order

1. Resource group
2. Network, Log Analytics, Automation account (parallel)
3. VMs (parallel, depend on network subnet)
4. Maintenance configurations (parallel with VMs)
5. Dynamic scope assignment (depends on maintenance configs)
6. Static scope assignment (depends on VMs + maintenance configs)
7. Policy assignment + remediation (depends on VMs existing)
8. Resource Graph queries, workbook, alerting (depend on Log Analytics / VMs for correctness)

See [PLAN.md](../PLAN.md) for the full table with estimated wall-clock time per step.
