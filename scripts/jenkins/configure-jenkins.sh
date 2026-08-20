#!/usr/bin/env bash

set -euo pipefail

JENKINS_NAMESPACE="${JENKINS_NAMESPACE:-jenkins}"
APPLICATION_NAMESPACE="${APPLICATION_NAMESPACE:-devops-app}"

JCASC_CONFIGMAP_NAME="${JCASC_CONFIGMAP_NAME:-jenkins-jcasc}"
JCASC_FILE="${JCASC_FILE:-jenkins/jcasc/jenkins.yaml}"
JOBS_FILE="${JOBS_FILE:-jenkins/jobs/jobs.groovy}"
JCASC_LABEL_KEY="${JCASC_LABEL_KEY:-jenkins-jenkins-config}"

CI_RBAC_FILE="${CI_RBAC_FILE:-jenkins/rbac/ci-rbac.yaml}"
CD_RBAC_FILE="${CD_RBAC_FILE:-jenkins/rbac/cd-rbac.yaml}"

for required_file in \
  "${JCASC_FILE}" \
  "${JOBS_FILE}" \
  "${CI_RBAC_FILE}" \
  "${CD_RBAC_FILE}"
do
  if [[ ! -f "${required_file}" ]]; then
    echo "ERROR: Required file was not found: ${required_file}" >&2
    exit 1
  fi
done

for required_command in terraform kubectl envsubst; do
  if ! command -v "${required_command}" >/dev/null 2>&1; then
    echo "ERROR: Required command was not found: ${required_command}" >&2
    exit 1
  fi
done

JENKINS_CI_ROLE_ARN="$(
  terraform output -raw jenkins_ci_role_arn
)"

if [[ -z "${JENKINS_CI_ROLE_ARN}" ]]; then
  echo "ERROR: Terraform output jenkins_ci_role_arn is empty." >&2
  exit 1
fi

export JENKINS_CI_ROLE_ARN

echo "Creating required namespaces..."

kubectl create namespace "${JENKINS_NAMESPACE}" \
  --dry-run=client \
  --output yaml |
  kubectl apply -f -

kubectl create namespace "${APPLICATION_NAMESPACE}" \
  --dry-run=client \
  --output yaml |
  kubectl apply -f -

echo "Creating Jenkins credentials..."

bash scripts/jenkins/create-credentials.sh

echo "Applying Jenkins CI ServiceAccount with IRSA..."

envsubst '${JENKINS_CI_ROLE_ARN}' \
  < "${CI_RBAC_FILE}" |
  kubectl apply -f -

echo "Applying Jenkins CD ServiceAccount and RBAC..."

kubectl apply -f "${CD_RBAC_FILE}"

echo "Creating or updating Jenkins JCasC and Job DSL ConfigMap..."

kubectl create configmap "${JCASC_CONFIGMAP_NAME}" \
  --namespace "${JENKINS_NAMESPACE}" \
  --from-file=jenkins.yaml="${JCASC_FILE}" \
  --from-file=jobs.groovy="${JOBS_FILE}" \
  --dry-run=client \
  --output yaml |
  kubectl apply -f -

echo "Adding the label required by the Jenkins JCasC sidecar..."

kubectl label configmap "${JCASC_CONFIGMAP_NAME}" \
  --namespace "${JENKINS_NAMESPACE}" \
  "${JCASC_LABEL_KEY}=true" \
  --overwrite

echo "Jenkins credentials, RBAC, JCasC and Job DSL are ready."