#!/usr/bin/env bash

set -euo pipefail

JENKINS_NAMESPACE="${JENKINS_NAMESPACE:-jenkins}"
APPLICATION_NAMESPACE="${APPLICATION_NAMESPACE:-devops-app}"
CD_SERVICE_ACCOUNT="${CD_SERVICE_ACCOUNT:-jenkins-cd-agent}"

CD_IDENTITY="system:serviceaccount:${JENKINS_NAMESPACE}:${CD_SERVICE_ACCOUNT}"

echo "Checking Jenkins CD ServiceAccount..."

kubectl get serviceaccount "${CD_SERVICE_ACCOUNT}" \
  --namespace "${JENKINS_NAMESPACE}" \
  --output yaml

echo "Verifying deployment permissions in ${APPLICATION_NAMESPACE}..."

for verb in get list watch create update patch delete; do
  kubectl auth can-i "${verb}" deployments \
    --namespace "${APPLICATION_NAMESPACE}" \
    --as "${CD_IDENTITY}" |
    grep -q '^yes$'
done

echo "Verifying that CD cannot deploy to default..."

if kubectl auth can-i create deployments \
  --namespace default \
  --as "${CD_IDENTITY}" |
  grep -q '^yes$'
then
  echo "ERROR: CD ServiceAccount must not deploy to default." >&2
  exit 1
fi

echo "Verifying that CD has no cluster-wide node access..."

if kubectl auth can-i list nodes \
  --as "${CD_IDENTITY}" |
  grep -q '^yes$'
then
  echo "ERROR: CD ServiceAccount must not list cluster nodes." >&2
  exit 1
fi

echo "CD ServiceAccount permissions are correctly restricted."