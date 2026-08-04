#!/usr/bin/env bash

set -euo pipefail

JENKINS_NAMESPACE="${JENKINS_NAMESPACE:-jenkins}"
JENKINS_RELEASE="${JENKINS_RELEASE:-jenkins}"
JENKINS_CHART_VERSION="${JENKINS_CHART_VERSION:-5.9.49}"

STORAGE_CLASS_FILE="${STORAGE_CLASS_FILE:-jenkins/storage/storageclass.yaml}"
JENKINS_VALUES_FILE="${JENKINS_VALUES_FILE:-jenkins/values.yaml}"
CI_AGENT_FILE="${CI_AGENT_FILE:-jenkins/agents/ci-agent.yaml}"
CD_AGENT_FILE="${CD_AGENT_FILE:-jenkins/agents/cd-agent.yaml}"

for required_file in \
  "${STORAGE_CLASS_FILE}" \
  "${JENKINS_VALUES_FILE}" \
  "${CI_AGENT_FILE}" \
  "${CD_AGENT_FILE}"
do
  if [[ ! -f "${required_file}" ]]; then
    echo "ERROR: Required file was not found: ${required_file}" >&2
    exit 1
  fi
done

echo "Creating Jenkins namespace if it does not exist..."

kubectl create namespace "${JENKINS_NAMESPACE}" \
  --dry-run=client \
  --output yaml |
  kubectl apply -f -

echo "Applying Jenkins StorageClass..."

kubectl apply -f "${STORAGE_CLASS_FILE}"

echo "Applying ServiceAccounts, RBAC and JCasC..."

bash scripts/jenkins/configure-jenkins.sh

echo "Adding the official Jenkins Helm repository..."

helm repo add jenkins https://charts.jenkins.io \
  --force-update

echo "Updating Helm repositories..."

helm repo update

echo "Installing Jenkins Helm chart version ${JENKINS_CHART_VERSION}..."

helm upgrade --install "${JENKINS_RELEASE}" jenkins/jenkins \
  --namespace "${JENKINS_NAMESPACE}" \
  --version "${JENKINS_CHART_VERSION}" \
  --values "${JENKINS_VALUES_FILE}" \
  --set-file "agent.podTemplates.ci=${CI_AGENT_FILE}" \
  --set-file "agent.podTemplates.cd=${CD_AGENT_FILE}" \
  --wait \
  --timeout 10m

echo "Jenkins installation completed."
echo
echo "Run the following command to access the Jenkins UI:"
echo "kubectl port-forward service/${JENKINS_RELEASE} 8080:8080 -n ${JENKINS_NAMESPACE}"