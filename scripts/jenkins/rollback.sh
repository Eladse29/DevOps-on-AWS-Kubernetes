#!/usr/bin/env bash

set -euo pipefail

APPLICATION_NAMESPACE="${APPLICATION_NAMESPACE:-devops-app}"
ROLLBACK_TIMEOUT="${ROLLBACK_TIMEOUT:-5m}"

RELEASES=(
  worker
  backend
  frontend
)

if ! command -v helm >/dev/null 2>&1; then
  echo "ERROR: helm is required but was not found." >&2
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl is required but was not found." >&2
  exit 1
fi

echo "Current Helm releases in ${APPLICATION_NAMESPACE}:"

helm list \
  --namespace "${APPLICATION_NAMESPACE}"

echo

for release in "${RELEASES[@]}"; do
  if ! helm status "${release}" \
    --namespace "${APPLICATION_NAMESPACE}" \
    >/dev/null 2>&1
  then
    echo "Skipping ${release}: release does not exist."
    continue
  fi

  current_revision="$(
    helm history "${release}" \
      --namespace "${APPLICATION_NAMESPACE}" \
      --output json |
    grep -o '"revision":[0-9]*' |
    tail -n 1 |
    cut -d: -f2
  )"

  if [[ -z "${current_revision}" || "${current_revision}" -le 1 ]]; then
    echo "Skipping ${release}: no previous revision is available."
    continue
  fi

  previous_revision="$((current_revision - 1))"

  echo "Rolling back ${release}: revision ${current_revision} -> ${previous_revision}"

  helm rollback "${release}" "${previous_revision}" \
    --namespace "${APPLICATION_NAMESPACE}" \
    --wait \
    --timeout "${ROLLBACK_TIMEOUT}"
done

echo
echo "Waiting for application rollouts..."

for deployment in worker backend frontend; do
  if kubectl get deployment "${deployment}" \
    --namespace "${APPLICATION_NAMESPACE}" \
    >/dev/null 2>&1
  then
    kubectl rollout status "deployment/${deployment}" \
      --namespace "${APPLICATION_NAMESPACE}" \
      --timeout=180s
  fi
done

echo
echo "Rollback process completed."

kubectl get deployments,pods,services \
  --namespace "${APPLICATION_NAMESPACE}" \
  --output wide