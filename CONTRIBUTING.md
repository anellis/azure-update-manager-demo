# Contributing

This is a demo repository, kept intentionally small. Contributions are welcome for bug fixes,
cost optimizations, and clarity improvements.

## Branching model

- `main` — always deployable, demo-ready. **Protected by convention**: do not push directly to
  `main`; open a pull request from `dev` (or a feature branch) and merge after CI passes. Branch
  protection rules are not enforced via the GitHub API/admin settings in this repo — enable them
  in the repo's Settings → Branches if you want them enforced server-side.
- `dev` — integration branch for day-to-day changes. Branch from `dev` for new work, open PRs
  back into `dev`, then periodically fast-forward/PR `dev` into `main` once validated.

## Pull requests

- All PRs that touch `bicep/**` run [.github/workflows/bicep-validate.yml](.github/workflows/bicep-validate.yml),
  which runs `az bicep build` and `az deployment group validate --what-if` via OIDC federated
  credentials (no secrets stored in the repo — see the workflow file for required GitHub secrets).
- Keep module boundaries intact (see [PLAN.md](PLAN.md) for the module decomposition) — avoid
  collapsing multiple resource types into one module.
- Never commit secrets, admin passwords, SSH private keys, or customer-identifying names/tags.

## Code style

- Bicep: one resource type's concerns per module, `@description()` on every parameter, secure
  parameters marked `@secure()`.
- PowerShell scripts: `$ErrorActionPreference` set explicitly, no inline credentials.
