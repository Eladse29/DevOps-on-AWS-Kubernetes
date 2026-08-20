#!/usr/bin/env bash

set -euo pipefail

JENKINS_NAMESPACE="${JENKINS_NAMESPACE:-jenkins}"
JCASC_CONFIGMAP_NAME="${JCASC_CONFIGMAP_NAME:-jenkins-jcasc}"

echo "Applying Jenkins Job DSL configuration..."

bash scripts/jenkins/configure-jenkins.sh

echo "Waiting for Jenkins controller to be Ready..."

kubectl rollout status statefulset/jenkins \
  --namespace "${JENKINS_NAMESPACE}" \
  --timeout=300s

echo "Verifying that the JCasC ConfigMap contains the Job DSL file..."

kubectl get configmap "${JCASC_CONFIGMAP_NAME}" \
  --namespace "${JENKINS_NAMESPACE}" \
  --output jsonpath='{.data.jobs\.groovy}' |
  grep -q "pipelineJob('application-ci')"

kubectl get configmap "${JCASC_CONFIGMAP_NAME}" \
  --namespace "${JENKINS_NAMESPACE}" \
  --output jsonpath='{.data.jobs\.groovy}' |
  grep -q "pipelineJob('application-cd')"

echo "Job DSL configuration contains application-ci and application-cd."
echo "The JCasC sidecar will reload the configuration automatically."