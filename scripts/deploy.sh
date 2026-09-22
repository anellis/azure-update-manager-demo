#!/usr/bin/env bash
set -Eeuo pipefail

SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-c69f7b0e-bf5b-4e01-b8c9-5a9fd00dae85}"
TENANT_ID="${TENANT_ID:-46d3e391-bd8a-44cb-a6f7-10ff4b3405ef}"
LOCATION="${LOCATION:-eastus2}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARAM_FILE="${ROOT_DIR}/infra/parameters/demo.bicepparam"
START_TIME="$(date +%s)"

step() { printf '\033[36m[%s] %s\033[0m\n' "$(date +%H:%M:%S)" "$1"; }
ok() { printf '\033[32m[%s] OK  %s\033[0m\n' "$(date +%H:%M:%S)" "$1"; }

step 'Checking Azure CLI login.'
CURRENT_TENANT="$(az account show --query tenantId -o tsv 2>/dev/null || true)"
if [[ -z "${CURRENT_TENANT}" ]]; then
  echo "Run: az login --tenant ${TENANT_ID}" >&2
  exit 1
fi
[[ "${CURRENT_TENANT}" == "${TENANT_ID}" ]] || { echo "Wrong tenant: ${CURRENT_TENANT}" >&2; exit 1; }
az account set --subscription "${SUBSCRIPTION_ID}"
ok "Using tenant ${TENANT_ID} and subscription ${SUBSCRIPTION_ID}."

step 'Registering required resource providers.'
for provider in Microsoft.Compute Microsoft.Network Microsoft.Insights Microsoft.Maintenance Microsoft.PolicyInsights Microsoft.Automation Microsoft.OperationalInsights; do
  az provider register --namespace "${provider}" --wait >/dev/null
  ok "Registered ${provider}"
done

step 'Checking required deployment environment variables.'
for variable in AUM_ADMIN_PUBLIC_IP_CIDR AUM_ALERT_EMAIL AUM_ADMIN_PASSWORD; do
  [[ -n "${!variable:-}" ]] || { echo "Set ${variable} before deploying. No secret is read from the repository." >&2; exit 1; }
done

step "Running subscription what-if from ${PARAM_FILE}."
az deployment sub what-if --location "${LOCATION}" --parameters "${PARAM_FILE}" --template-file "${ROOT_DIR}/infra/main.bicep"
ok 'What-if completed.'

step 'Starting subscription deployment.'
az deployment sub create --name "aumdemo-$(date +%Y%m%d%H%M%S)" --location "${LOCATION}" --parameters "${PARAM_FILE}" --template-file "${ROOT_DIR}/infra/main.bicep"
ok 'Deployment completed.'

ELAPSED=$(( $(date +%s) - START_TIME ))
printf '\033[32mTotal elapsed: %02d:%02d:%02d\033[0m\n' $((ELAPSED/3600)) $(((ELAPSED%3600)/60)) $((ELAPSED%60))
echo 'Run scripts/validate.ps1 next.'
