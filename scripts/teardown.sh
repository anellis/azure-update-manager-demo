#!/usr/bin/env bash
set -Eeuo pipefail

SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-c69f7b0e-bf5b-4e01-b8c9-5a9fd00dae85}"
RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-rg-aum-demo-eastus2}"
NAME_PREFIX="${NAME_PREFIX:-aumdemo}"
FORCE="${FORCE:-false}"
NO_WAIT="${NO_WAIT:-false}"

az account set --subscription "${SUBSCRIPTION_ID}"

if [[ "${FORCE}" != "true" ]]; then
  read -r -p "Type '${RESOURCE_GROUP_NAME}' to delete the demo and its subscription-scoped resources: " confirmation
  [[ "${confirmation}" == "${RESOURCE_GROUP_NAME}" ]] || {
    echo 'Confirmation did not match; nothing was deleted.' >&2
    exit 1
  }
fi

resource_group_scope="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}"
subscription_scope="/subscriptions/${SUBSCRIPTION_ID}"

for scope in "${resource_group_scope}" "${subscription_scope}"; do
  for policy_name in "${NAME_PREFIX}-periodic-assessment" "${NAME_PREFIX}-periodic-assess"; do
    while IFS=$'\t' read -r policy_id principal_id; do
      [[ -n "${policy_id}" ]] || continue

      if [[ -n "${principal_id}" ]]; then
        while IFS= read -r role_id; do
          [[ -n "${role_id}" ]] || continue
          echo "Removing policy-created role assignment ${role_id}"
          az role assignment delete --ids "${role_id}"
        done < <(az role assignment list --assignee-object-id "${principal_id}" --all --query '[].id' -o tsv)
      fi

      echo "Removing policy assignment ${policy_id}"
      policy_scope="${policy_id%/providers/Microsoft.Authorization/policyAssignments/*}"
      az policy assignment delete --name "${policy_name}" --scope "${policy_scope}"
    done < <(
      az policy assignment list \
        --scope "${scope}" \
        --query "[?name=='${policy_name}'].{id:id,principalId:identity.principalId}" \
        -o tsv
    )
  done
done

for assignment_name in dynamic-0 dynamic-1 dynscope-prod-monthly dynscope-nonprod-weekly; do
  assignment_id="${subscription_scope}/providers/Microsoft.Maintenance/configurationAssignments/${assignment_name}"
  assignment_json="$(az resource show --ids "${assignment_id}" --api-version 2023-04-01 -o json 2>/dev/null)" || {
    status=$?
    [[ ${status} -eq 3 ]] && continue
    echo "Failed to inspect ${assignment_id}." >&2
    exit "${status}"
  }

  targets_group="$(az resource show --ids "${assignment_id}" --api-version 2023-04-01 --query "contains(properties.filter.resourceGroups, '${RESOURCE_GROUP_NAME}')" -o tsv)"
  maintenance_id="$(az resource show --ids "${assignment_id}" --api-version 2023-04-01 --query properties.maintenanceConfigurationId -o tsv)"
  if [[ "${targets_group}" == "true" || "${maintenance_id}" == "${resource_group_scope}/"* ]]; then
    echo "Removing subscription-scoped configuration assignment ${assignment_id}"
    az resource delete --ids "${assignment_id}" --api-version 2023-04-01
  fi
done

echo "Deleting resource group ${RESOURCE_GROUP_NAME}."
delete_args=(group delete --name "${RESOURCE_GROUP_NAME}" --yes)
if [[ "${NO_WAIT}" == "true" ]]; then
  delete_args+=(--no-wait)
fi
az "${delete_args[@]}"

if [[ "${NO_WAIT}" == "true" ]]; then
  echo "Deletion requested for ${RESOURCE_GROUP_NAME}; subscription-scoped resources were removed first."
  exit 0
fi

[[ "$(az group exists --name "${RESOURCE_GROUP_NAME}" -o tsv)" == "false" ]] || {
  echo "Resource group ${RESOURCE_GROUP_NAME} still exists after deletion completed." >&2
  exit 1
}

echo 'Teardown verified: the resource group, demo policies, policy identity roles, and dynamic configuration assignments are gone.'
