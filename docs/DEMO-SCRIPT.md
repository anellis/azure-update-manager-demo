# Azure Update Manager — presenter runbook

This is a 45-minute live walkthrough followed by 15 minutes of Q&A. The lab is deliberately
small: two Windows Server 2022 VMs, one Windows Server 2019 VM, and three Ubuntu 22.04 VMs in
`rg-aum-demo-eastus2`. RHEL is not deployed in this subscription because paid Red Hat marketplace
images are blocked here. Say that plainly if the customer asks.

## If I am short on time: five-minute path

1. **Update Manager > Overview:** show the compliance rollup and explain that this is the control
   plane replacing fragmented WSUS/SCCM reporting for the Azure and Arc-connected estate.
2. **Machines:** filter `OS = Windows`, then `Environment = NonProd`; open the intentionally
   unassessed Ubuntu VM and show its assessment state.
3. **Maintenance configurations:** open `Prod-Monthly-Sunday-2AM`, show classifications and reboot
   setting, then show the dynamic tag scope.
4. **History:** open the one submitted Linux `installPatches` run. If it is still pending, say so
   and show the operation status rather than presenting it as complete.
5. **Close:** Arc, governance, and migration path from WSUS/SCCM are the next conversation; this
   lab does not contain on-prem machines.

## Pre-flight: 30 minutes before the call

| Check | Action |
|---|---|
| Azure context | Confirm the correct tenant, subscription, and resource group. Keep the portal open at `Update Manager` and `rg-aum-demo-eastus2`. |
| VMs | Confirm all six VMs are running: `aumdemo-win22-prod-01`, `aumdemo-win22-prod-02`, `aumdemo-win19-prod-01`, `aumdemo-ubuntu22-nonprod-01`, `aumdemo-ubuntu22-nonprod-02`, `aumdemo-ubuntu22-nonprod-03`. |
| Assessment | Run `scripts/seed-demo.ps1` at least 20 minutes ahead. Confirm five assessments were submitted and the intentionally skipped VM is known. |
| Data freshness | Refresh Overview and Machines. Assessment and Resource Graph results can take 10–30 minutes. Do not promise exact counts until the blade has refreshed. |
| Schedule | Confirm `Prod-Monthly-Sunday-2AM` and `NonProd-Weekly-Friday-10PM` exist and show the intended classifications/reboot settings. |
| History | Confirm the one Linux `installPatches` operation is visible, or prepare the honest fallback: “submitted; still processing.” |
| Reporting | Open the workbook gallery and Log Analytics Logs. The four `.kql` files are in `/kql`; saved searches may be empty if Heartbeat/Update data sources are not connected. |
| Alerts | Open the failed patch action group and alert. It will have no fired history unless a real patch operation fails. |
| Screen share | Use 1920×1080 or better, browser zoom 90–100%, and close unrelated tabs, subscriptions, tenant names, tokens, and personal data. |
| Names | Use the generic demo names on screen. Do not show internal subscription naming or customer-identifying tags. |
| Backup | Have a labeled screenshot of the compliance and History views. It is a backup, not live evidence. |

## 45-minute runbook

| Step | Time | Where I click (exact portal path) | What I say (2–4 natural spoken sentences, first person, conversational — not marketing copy) | What they should take away | Fallback if it breaks |
|---|---:|---|---|---|---|
| 1. Set the stage | 3 min | I open **Azure portal > Update Manager** and keep the subscription/resource-group context visible. | “I’m going to show the operating model I would use for a mixed Azure and on-prem estate. The customer problem is familiar: WSUS and SCCM still do useful work, but reporting, ownership, and patch exceptions get difficult across subscriptions and locations. I’ll treat this as a regulated GxP conversation: evidence, approvals, maintenance windows, and rollback decisions matter as much as the install itself.” | Update Manager is the Azure control plane to evaluate alongside the existing WSUS/SCCM estate; it is not an overnight replacement claim. | If the portal is slow, use the architecture diagram and state that every live machine in this lab is an Azure VM; Arc is discussed, not shown. |
| 2. Update Manager overview | 5 min | **Azure portal > Update Manager > Overview**; select the target subscription and resource group. | “This is the estate-level view I use first. I’m looking for the compliance rollup, assessment freshness, and the difference between machines that are current, missing updates, or not assessed. In production I would scope this across the management groups and subscriptions that own the regulated workloads.” | One place to start compliance review, with scope and freshness visible before anyone talks about installing a patch. | If the rollup is still empty, open **Resource Graph Explorer** and use the Update Manager patch assessment resources; label any screenshot as captured earlier. |
| 3. Machines view | 5 min | **Update Manager > Machines**; use filters for **Operating system**, **Resource group**, **Tags**, and **Assessment status**. | “I’m narrowing the view the way an operations team actually works: first by operating system, then by environment or patch group, then by assessment state. I’ll open `aumdemo-ubuntu22-nonprod-03`, which was intentionally left out of the seed assessment. That is useful because an unassessed machine is a governance problem even when I have no evidence that it is missing a specific patch.” | Filters and tags turn a large estate into an actionable work queue; “unknown” is not treated as compliant. | If the machine has already been assessed, show the assessment timestamp and explain that the deliberate stale-state scenario has expired; use the backup screenshot. |
| 4. Enable periodic assessment live | 4 min | **Update Manager > Machines > select VM > Update settings > Periodic assessment > Enable**; save. | “I’m enabling periodic assessment on the machine where it is off. This does not mean the machine is patched immediately; it establishes the recurring assessment behavior. The normal cadence is up to 24 hours, so I set expectations that the compliance state will not necessarily change during this minute of the demo.” | Assessment and installation are separate controls; periodic assessment produces evidence on a cadence rather than on demand. | If the blade does not allow the change, show the VM’s patch settings and the periodic-assessment policy assignment; explain that policy is the scale mechanism. |
| 5. Update settings and orchestration | 5 min | **Update Manager > Machines > select VM > Update settings**; compare the patch orchestration setting on three VMs. | “I use Customer Managed Schedules when the application owner controls the maintenance window and I need the schedule to be explicit. Azure-orchestrated patching is appropriate when Azure can choose an eligible window and the platform-managed behavior is acceptable. Manual is an exception path here, not a compliance strategy; it gives the team control but also leaves more process outside the service.” | The modes are operational choices tied to ownership and change control, not three labels for the same behavior. | If the portal hides a mode, show the VM resource JSON patch settings or the schedule assignment and explain the intended mapping. |
| 6. Schedules | 7 min | **Update Manager > Maintenance configurations**; open `Prod-Monthly-Sunday-2AM`, then `NonProd-Weekly-Friday-10PM`. | “For production I have a monthly Sunday window with Critical and Security classifications and an `IfRequired` reboot. Non-production is weekly on Friday night, includes the broader update set, and uses an `Always` reboot so the outcome is predictable. In a real validated system I would also show the approved KB/package include and exclude list and the change record tied to this configuration; this small lab does not have a real application approval workflow behind it.” | Maintenance configuration is where timing, classification, reboot behavior, and scope become reviewable policy. | If a schedule page is unavailable, use **Resource group > Deployments** or the Bicep parameters to show the exact values, and say portal rendering is the issue. |
| 7. Dynamic scope by tag | 6 min | **Virtual machines > select `aumdemo-ubuntu22-nonprod-02` > Properties > Tags**; set `Environment=Prod`, save; then **Update Manager > Maintenance configurations > Prod-Monthly-Sunday-2AM > Assignments**. | “This is the scale moment. I’m changing one tag, not editing a list of resource IDs, and the machine should resolve into the Prod dynamic scope. In a real estate that distinction matters: onboarding a hundred machines is a tag and policy operation, not a hundred manual schedule assignments.” | Dynamic scope separates fleet membership from schedule definition and reduces assignment drift. | If the assignment view has not refreshed, show the saved tag immediately, then refresh after a minute and explain the control-plane propagation delay. Restore the original `Environment=NonProd` tag after the demo if needed. |
| 8. One-time update and History | 4 min | **Update Manager > Machines > select `aumdemo-ubuntu22-nonprod-01` > One-time update / Install updates**; choose Critical/Security and submit; then **Update Manager > History**. | “I’m submitting one on-demand install so we have a real operation to follow. I’m watching the operation state rather than narrating success before the service reports it. The important point is the evidence chain: target, classifications, reboot choice, start time, result, and any failure details.” | On-demand work is auditable and distinct from a recurring maintenance schedule. | If the run is still pending, show the submitted operation and say exactly that. If it fails, that is valuable History and alert evidence; do not retry until you have captured the error. |
| 9. Policy and RBAC | 4 min | **Azure Policy > Assignments**; open `aumdemo-periodic-assessment`; then **Access control (IAM) > Role assignments** at the resource group. | “The policy is the scale-out guardrail for periodic assessment. Its managed identity gets only the role needed for remediation at the selected scope, while operators can be delegated through resource-group or management-group RBAC. For a GxP workload I would separate policy administration, patch approval, execution, and evidence review rather than give one team permanent Owner.” | Policy and RBAC turn an operational preference into enforceable governance with separation of duties. | If remediation is still pending, show the assignment and remediation state; say “in progress,” not “enforced.” |
| 10. Reporting and alerting | 4 min | **Monitor > Workbooks > Templates > Update Manager**; then **Log Analytics workspace > Logs**; finally **Monitor > Alerts > Alert rules**. | “The workbook is where I want the recurring review to live, while the KQL files give an operations team starting queries they can adapt. This lab’s four saved searches are compliance by OS, missing Critical/Security updates, patch run history, and no assessment in 24 hours. I’ll also show the failed-install alert; its history is expected to be empty unless we create a real failed operation.” | Reporting is a review surface, not a substitute for change control; alert history is meaningful only when an actual failure occurs. | If workbook data is not populated, use the Machines and History blades plus Resource Graph. If Log Analytics tables are empty, say the saved queries exist but the corresponding telemetry source is not connected in this lab. |
| 11. Close and next steps | 3 min | I return to **Update Manager > Overview**, then open **Azure Arc > Servers** only if a real Arc resource is available. | “For on-prem and other clouds, Arc is the bridge that brings supported servers into this same management conversation; I have not onboarded an on-prem machine in this lab, so I won’t pretend this screen proves that path. ESU is the conversation for supported legacy Windows Server and SQL Server versions, hotpatching is a separate capability with eligibility constraints, and pre/post events need a real application integration. My next step would be a discovery workshop: inventory, network path, maintenance ownership, evidence requirements, and a coexistence plan with WSUS/SCCM.” | The demo proves the Azure control-plane mechanics; production adoption requires Arc onboarding, licensing validation, network design, application/change-control integration, and a phased migration. | If time is gone, state the three next steps verbally: validate one workload, prove coexistence, then expand by tag and policy. |

## What is real in this lab, and what is simulated

**Real:** six Azure VMs, Windows/Linux Update Manager assessment settings, maintenance configurations,
dynamic and static assignment resources, periodic-assessment policy assignment, Azure Monitor Agent,
Log Analytics workspace, and the submitted `installPatches` operation. The portal behavior and service
latency are real Azure behavior.

**Simulated or limited:** on-prem/other-cloud Arc onboarding; GxP validation evidence and approval
records; application-aware pre/post actions; a real pharmaceutical workload; RHEL, because this
subscription cannot purchase the paid marketplace image; and a guaranteed populated legacy `Update`
table in Log Analytics. The workbook may need to be gallery-launched and saved in the portal rather
than created by this lab deployment. The `PrePostPatch-TalkTrack-Stub` is only a talk-track artifact.

## Customer questions

| Question | Crisp answer |
|---|---|
| What does it cost? | Update Manager has service-specific pricing considerations; compute, storage, Log Analytics ingestion/retention, Arc-enabled servers, and any premium capabilities still apply. I would price the discovered estate and retention requirement rather than quote from this six-VM lab. |
| What are Arc prerequisites? | A supported server, Azure Connected Machine agent, Azure resource identity, and outbound connectivity to required Azure endpoints over HTTPS/443. No inbound connection from Azure to the server is required. Private Link is an option where the network and supported services justify it; validate endpoint, DNS, proxy, and firewall requirements during design. |
| Can WSUS/SCCM coexist with this? | Yes, but define authority per machine and update class. A sensible migration is assess first, pilot a ring, keep existing approval/change processes, move scheduling and reporting in stages, and avoid two tools independently installing the same updates on one machine. |
| What about third-party patching? | Coverage depends on the OS, product, repository, and Update Manager support. Do not assume every third-party application is covered; keep an application/vendor patch process for gaps. |
| Does this patch SQL Server? | Update Manager patches the guest OS and supported update categories. SQL Server servicing, CU approval, HA coordination, backups, and application validation remain a separate SQL/change-management concern. ESU licensing for eligible legacy versions is also separate. |
| How does this fit change control and validated systems? | Treat the maintenance configuration, scope, classifications, reboot behavior, approval, evidence, and post-patch verification as controlled records. Validate the actual workload and SOPs; this demo is not GxP validation evidence. |
| What is the RBAC model? | Separate platform administration, policy/remediation, patch operators, and read-only evidence reviewers. Assign at the smallest practical scope and use managed identities for remediation rather than shared credentials. |
| What about air-gapped manufacturing systems? | An actually disconnected system cannot use the normal Arc/Azure control path without an approved connectivity design. Plan a connected management zone, proxy/private connectivity, or a separate offline process; do not claim this lab covers air-gapped operation. |
| Can reporting feed our ITSM? | Yes, through supported APIs, Resource Graph, Activity Log, Log Analytics, automation, and your ITSM connector pattern. Define the event schema, ownership, deduplication, evidence retention, and approval workflow before automating tickets. |

## Presenter notes

- Say “assessment result” and “installation result” separately.
- Never call the skipped assessment machine compliant or non-compliant based only on “Unknown.”
- If a result is still processing, show the state and timestamp; that is more credible than forcing a green screen.
- Keep [real-vs-simulated.md](real-vs-simulated.md) open in a background tab for direct questions.
