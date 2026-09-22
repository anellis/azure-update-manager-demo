# What's Real vs. Simulated

Use this list to avoid ever misrepresenting the demo to the customer.

| Claim | Status | Notes |
|---|---|---|
| Update compliance assessment (periodic + on-demand) | **Real** | Live Azure Update Manager assessment on Azure VMs |
| Patch installation via scheduled maintenance configurations | **Real** | `Microsoft.Maintenance/maintenanceConfigurations` |
| Customer Managed Schedules / Azure-orchestrated / Manual orchestration | **Real** | Distinct `patchMode`/`assessmentMode` per VM |
| Dynamic scoping by tag | **Real** | `Microsoft.Maintenance/configurationAssignments` with `tagSettings` filter |
| Static/direct assignment | **Real** | Direct `configurationAssignments` extension resource on `vm-rhel9-prod` |
| Policy-enforced periodic assessment | **Real** | Built-in initiative assignment + DINE remediation |
| Windows + Linux mixed OS (2022/2019/Ubuntu 22.04/RHEL 9) | **Real** | All deployed as Azure VMs |
| Hybrid / Arc-managed on-prem servers | **Simulated** | No on-prem hosts or Arc onboarding in this environment — VMs are tagged/narrated to represent the story only |
| Pre/post maintenance "app-aware" automation | **Simulated stub** | Automation runbook `PrePostPatch-Stub` only logs narration text; not integrated with any real application, load balancer, or database |
| Extended Security Updates (ESU) | **Not deployed** | Talk-track only |
| Hotpatching | **Not deployed** | Talk-track only |
| Reporting workbook data source | **Real, but not classic Log Analytics Update Management** | Sourced from Azure Resource Graph (`patchassessmentresources`/`patchinstallationresources`), blended with a Log Analytics tile for the alert signal |
