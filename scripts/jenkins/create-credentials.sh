#!/usr/bin/env bash

set -euo pipefail

JENKINS_NAMESPACE="${JENKINS_NAMESPACE:-jenkins}"
BACKEND_VALUES_FILE="${BACKEND_VALUES_FILE:-helm/backend/values.local.yaml}"

SECRET_NAME="${SECRET_NAME:-jenkins-backend-values}"
SECRET_KEY="${SECRET_KEY:-backend-values-base64}"

if [[ ! -f "${BACKEND_VALUES_FILE}" ]]; then
  echo "ERROR: Backend values file was not found: ${BACKEND_VALUES_FILE}" >&2
  echo "Create it from helm/backend/values.local.example.yaml." >&2
  exit 1
fi

if ! grep -qE '^[[:space:]]*dbPassword:[[:space:]]*".+"' \
  "${BACKEND_VALUES_FILE}"
then
  echo "ERROR: dbPassword is missing or empty in ${BACKEND_VALUES_FILE}." >&2
  exit 1
fi

kubectl create namespace "${JENKINS_NAMESPACE}" \
  --dry-run=client \
  --output yaml |
  kubectl apply -f -

echo "Encoding the backend Helm values..."

BACKEND_VALUES_BASE64="$(
  base64 --wrap=0 "${BACKEND_VALUES_FILE}"
)"

echo "Creating or updating the Jenkins credential source Secret..."

kubectl create secret generic "${SECRET_NAME}" \
  --namespace "${JENKINS_NAMESPACE}" \
  --from-literal="${SECRET_KEY}=${BACKEND_VALUES_BASE64}" \
  --dry-run=client \
  --output yaml |
  kubectl apply -f -

unset BACKEND_VALUES_BASE64

echo "Credential source Secret is ready."