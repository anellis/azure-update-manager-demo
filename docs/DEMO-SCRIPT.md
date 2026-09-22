# Demo Talk Track (45 minutes)

## 0-5 min — Setup & framing
- State the scenario: mixed Windows/Linux estate, compliance-driven patching.
- Call out up front: "Arc/on-prem is simulated via tags for narration — everything you see live is
  an Azure VM." See [real-vs-simulated.md](real-vs-simulated.md).

## 5-15 min — Compliance across the mixed estate
- Open the Update Manager workbook. Walk the compliance summary tile across all 8 VMs.
- Point out `vm-win19-nonprod` and `vm-rhel9-nonprod` showing stale/unknown status —
  explain periodic assessment is intentionally OFF (`assessmentMode=ImageDefault`) on these two.
- Show the missing critical/security tile — the 2 un-patched VMs seeded the night before.

## 15-25 min — Orchestration modes
- Show patch configuration blade on 3 VMs: Customer Managed Schedules, Azure-orchestrated
  automatic guest patching, Manual. Explain the difference in who controls timing.

## 25-33 min — Scheduled patching & scoping
- Open `Prod-Monthly-Sunday-2AM` and `NonProd-Weekly-Friday-10PM` maintenance configurations.
- Show dynamic scope: machines join by `Environment` tag, not resource ID — demonstrate by
  showing the assignment list resolves to VMs purely from the tag filter.
- Contrast with `vm-rhel9-prod`'s static/direct assignment — same schedule, different mechanism.

## 33-38 min — Policy & governance
- Show the periodic-assessment policy assignment and its compliance state.
- Narrate the DINE remediation task if not yet fully converged (be transparent about timing).

## 38-42 min — Alerting & app-aware patching
- Show the action group + activity log alert for failed patch installs.
- Show the Automation runbook `PrePostPatch-Stub` — explicitly label it a stub, describe how a
  real pre/post hook would drain traffic / validate app health.

## 42-45 min — Roadmap add-ons (talk only, not deployed)
- Extended Security Updates (ESU) for Windows Server 2012/2012 R2 — narrate licensing model.
- Hotpatching for Windows Server Azure Edition — narrate reboot-free CU patching.
- Arc-enabled servers for true on-prem/multi-cloud onboarding.
