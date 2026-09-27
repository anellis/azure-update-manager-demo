# What's Real vs. Simulated

Use this list to avoid ever misrepresenting the demo to the customer.

| Claim | Status | Notes |
|---|---|---|
| Update compliance assessment (periodic + on-demand) | **Real** | Live Azure Update Manager assessment on Azure VMs |
| Patch installation via scheduled maintenance configurations | **Real** | `Microsoft.Maintenance/maintenanceConfigurations` |
| Customer Managed Schedules / Azure-orchestrated / Manual orchestration | **Real** | Distinct `patchMode`/`assessmentMode` per VM |
| Dynamic scoping by tag | **Real** | `Microsoft.Maintenance/configurationAssignments` with `tagSettings` filter |
| Static/direct assignment | **Real** | Direct `configurationAssignments` extension resource on `aumdemo-ubuntu22-nonprod-01` |
| Policy-enforced periodic assessment | **Real** | Built-in policy assignment + deploy-if-not-exists remediation |
| Windows + Linux mixed OS (Windows Server 2022/2019 and Ubuntu 22.04) | **Real** | Six Azure VMs are deployed by the canonical `infra/` template |
| Hybrid / Arc-managed on-prem servers | **Simulated** | No on-prem hosts or Arc onboarding in this environment — VMs are tagged/narrated to represent the story only |
| Pre/post maintenance "app-aware" automation | **Simulated stub** | Automation runbook `PrePostPatch-Stub` only logs narration text; not integrated with any real application, load balancer, or database |
| Extended Security Updates (ESU) | **Not deployed** | Talk-track only |
| Hotpatching | **Not deployed** | Talk-track only |
| Shared reporting workbook | **Not deployed** | Use the first-party Update Manager workbook in the portal; Resource Graph remains authoritative for assessment and installation data |
