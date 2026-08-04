#!/usr/bin/env bash

set -euo pipefail

JENKINS_NAMESPACE="${JENKINS_NAMESPACE:-jenkins}"
JENKINS_RELEASE="${JENKINS_RELEASE:-jenkins}"
DELETE_PVC="${DELETE_PVC:-true}"
DELETE_NAMESPACE="${DELETE_NAMESPACE:-true}"
DELETE_STORAGE_CLASS="${DELETE_STORAGE_CLASS:-true}"

echo "Uninstalling Jenkins Helm release..."

helm uninstall "${JENKINS_RELEASE}" \
  --namespace "${JENKINS_NAMESPACE}" \
  --ignore-not-found

if [[ "${DELETE_PVC}" == "true" ]]; then
  echo "Deleting Jenkins PVC..."

  kubectl delete pvc \
    --namespace "${JENKINS_NAMESPACE}" \
    --all \
    --ignore-not-found
fi

echo "Deleting Jenkins-specific Secrets and ConfigMaps..."

kubectl delete secret jenkins-backend-values \
  --namespace "${JENKINS_NAMESPACE}" \
  --ignore-not-found

kubectl delete configmap jenkins-jcasc \
  --namespace "${JENKINS_NAMESPACE}" \
  --ignore-not-found

if [[ "${DELETE_NAMESPACE}" == "true" ]]; then
  echo "Deleting Jenkins namespace..."

  kubectl delete namespace "${JENKINS_NAMESPACE}" \
    --ignore-not-found
fi

if [[ "${DELETE_STORAGE_CLASS}" == "true" ]]; then
  echo "Deleting Jenkins StorageClass..."

  kubectl delete storageclass jenkins-ebs \
    --ignore-not-found
fi

echo "Jenkins resources were removed."