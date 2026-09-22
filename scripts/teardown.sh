#!/usr/bin/env bash
set -Eeuo pipefail

SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-c69f7b0e-bf5b-4e01-b8c9-5a9fd00dae85}"
RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-rg-aum-demo-eastus2}"
NAME_PREFIX="${NAME_PREFIX:-aumdemo}"
az account set --subscription "${SUBSCRIPTION_ID}"

while IFS= read -r assignment_id; do
  [[ -n "${assignment_id}" ]] && az resource delete --ids "${assignment_id}"
done < <(az resource list --resource-type Microsoft.Maintenance/configurationAssignments --query "[?contains(name, 'dynamic-')].id" -o tsv)

POLICY_ID="$(az policy assignment show --name "${NAME_PREFIX}-periodic-assessment" --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}" --query id -o tsv 2>/dev/null || true)"
if [[ -n "${POLICY_ID}" ]]; then az policy assignment delete --ids "${POLICY_ID}"; fi

az group delete --name "${RESOURCE_GROUP_NAME}" --yes --no-wait
echo "Deletion requested for ${RESOURCE_GROUP_NAME}."
