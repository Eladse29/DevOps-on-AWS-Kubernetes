#!/usr/bin/env bash

set -euo pipefail

JENKINS_NAMESPACE="${JENKINS_NAMESPACE:-jenkins}"
JENKINS_RELEASE="${JENKINS_RELEASE:-jenkins}"

echo "Checking Jenkins namespace..."

kubectl get namespace "${JENKINS_NAMESPACE}" >/dev/null

echo "Checking Jenkins Helm release..."

helm status "${JENKINS_RELEASE}" \
  --namespace "${JENKINS_NAMESPACE}"

echo "Checking Jenkins controller rollout..."

kubectl rollout status statefulset/jenkins \
  --namespace "${JENKINS_NAMESPACE}" \
  --timeout=300s

echo "Checking Jenkins controller Pod..."

kubectl get pods \
  --namespace "${JENKINS_NAMESPACE}" \
  --selector app.kubernetes.io/component=jenkins-controller \
  --output wide

echo "Checking Jenkins PVC..."

kubectl get pvc \
  --namespace "${JENKINS_NAMESPACE}"

echo "Checking Jenkins ServiceAccount..."

kubectl get serviceaccount jenkins-controller \
  --namespace "${JENKINS_NAMESPACE}"

echo "Checking CI and CD Agent ServiceAccounts..."

kubectl get serviceaccount jenkins-ci-agent \
  --namespace "${JENKINS_NAMESPACE}"

kubectl get serviceaccount jenkins-cd-agent \
  --namespace "${JENKINS_NAMESPACE}"

echo "Checking JCasC ConfigMap..."

kubectl get configmap jenkins-jcasc \
  --namespace "${JENKINS_NAMESPACE}" \
  --output jsonpath='{.metadata.labels.jenkins-jenkins-config}' |
  grep -qx 'true'

echo "Checking credential source Secret..."

kubectl get secret jenkins-backend-values \
  --namespace "${JENKINS_NAMESPACE}" >/dev/null

echo "Checking that the controller has zero executors..."

kubectl get configmap jenkins-jcasc \
  --namespace "${JENKINS_NAMESPACE}" \
  --output jsonpath='{.data.jenkins\.yaml}' |
  grep -q 'numExecutors: 0'

echo "Jenkins verification completed successfully."