#!/usr/bin/env bash

set -euo pipefail

JENKINS_NAMESPACE="${JENKINS_NAMESPACE:-jenkins}"
CI_SERVICE_ACCOUNT="${CI_SERVICE_ACCOUNT:-jenkins-ci-agent}"

echo "Checking Jenkins CI ServiceAccount..."

kubectl get serviceaccount "${CI_SERVICE_ACCOUNT}" \
  --namespace "${JENKINS_NAMESPACE}" \
  --output yaml

echo "Checking CI IRSA annotation..."

kubectl get serviceaccount "${CI_SERVICE_ACCOUNT}" \
  --namespace "${JENKINS_NAMESPACE}" \
  --output jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' |
  grep -q 'jenkins-ci-role'

echo "Verifying that CI cannot deploy to devops-app..."

if kubectl auth can-i create deployments \
  --namespace devops-app \
  --as "system:serviceaccount:${JENKINS_NAMESPACE}:${CI_SERVICE_ACCOUNT}" |
  grep -q '^yes$'
then
  echo "ERROR: CI ServiceAccount must not deploy applications." >&2
  exit 1
fi

echo "Verifying that CI cannot deploy to default..."

if kubectl auth can-i create deployments \
  --namespace default \
  --as "system:serviceaccount:${JENKINS_NAMESPACE}:${CI_SERVICE_ACCOUNT}" |
  grep -q '^yes$'
then
  echo "ERROR: CI ServiceAccount must not deploy to default." >&2
  exit 1
fi

echo "CI ServiceAccount permissions are correctly restricted."