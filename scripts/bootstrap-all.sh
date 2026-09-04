#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

AWS_REGION="${AWS_REGION:-us-east-1}"

SKIP_TERRAFORM=false
SKIP_DEMO=false
AUTO_APPROVE=false

usage() {
  cat <<'EOF'
Usage:
  bash scripts/bootstrap-all.sh [options]

Options:
  --skip-terraform   Do not create/update AWS infrastructure
  --skip-demo        Do not start local demo port-forwards/ngrok
  --yes              Apply Terraform without interactive confirmation
  -h, --help         Show this help

Examples:
  bash scripts/bootstrap-all.sh
  bash scripts/bootstrap-all.sh --yes
  bash scripts/bootstrap-all.sh --skip-terraform
  bash scripts/bootstrap-all.sh --skip-terraform --skip-demo
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-terraform)
      SKIP_TERRAFORM=true
      ;;
    --skip-demo)
      SKIP_DEMO=true
      ;;
    --yes)
      AUTO_APPROVE=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

trap 'echo; echo "ERROR: bootstrap failed at line $LINENO" >&2' ERR

section() {
  echo
  echo "============================================================"
  echo " $1"
  echo "============================================================"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: $1" >&2
    exit 1
  fi
}

section "PREFLIGHT"

for cmd in aws terraform kubectl helm python3 curl git; do
  require_command "${cmd}"
done

echo "Repository:"
git status --short
echo
echo "Branch: $(git branch --show-current)"
echo "Commit: $(git rev-parse --short HEAD)"

echo
echo "AWS identity:"
aws sts get-caller-identity

# ------------------------------------------------------------
# Terraform / AWS
# ------------------------------------------------------------

if [[ "${SKIP_TERRAFORM}" == false ]]; then
  section "TERRAFORM"

  terraform init
  terraform fmt -check -recursive
  terraform validate

  terraform plan -out=tfplan

  if [[ "${AUTO_APPROVE}" == true ]]; then
    terraform apply "tfplan"
  else
    echo
    read -r -p "Apply Terraform plan? [y/N] " answer

    case "${answer}" in
      y|Y|yes|YES)
        terraform apply "tfplan"
        ;;
      *)
        echo "Terraform apply cancelled."
        exit 0
        ;;
    esac
  fi
else
  section "TERRAFORM SKIPPED"
fi

# ------------------------------------------------------------
# EKS access
# ------------------------------------------------------------

section "EKS"

CLUSTER_NAME="$(
  terraform output -raw eks_cluster_name 2>/dev/null \
  || echo "infra-automation-dev-eks"
)"

echo "Cluster: ${CLUSTER_NAME}"
echo "Region:  ${AWS_REGION}"

aws eks update-kubeconfig \
  --region "${AWS_REGION}" \
  --name "${CLUSTER_NAME}"

echo
kubectl get nodes

# ------------------------------------------------------------
# Jenkins
# ------------------------------------------------------------

section "JENKINS"

bash scripts/jenkins/preflight.sh
bash scripts/jenkins/install-jenkins.sh
bash scripts/jenkins/configure-jenkins.sh
bash scripts/jenkins/create-credentials.sh
bash scripts/jenkins/create-jobs.sh
bash scripts/jenkins/verify-jenkins.sh

echo
echo "Jenkins runtime:"
kubectl get pods -n jenkins
kubectl get pvc -n jenkins
helm list -n jenkins

# ------------------------------------------------------------
# Observability validation
# ------------------------------------------------------------

section "OBSERVABILITY VALIDATION"

python3 scripts/observability/validate-observability.py

# ------------------------------------------------------------
# Prometheus / Grafana / Alertmanager
# ------------------------------------------------------------

section "OBSERVABILITY STACK"

helm repo add \
  prometheus-community \
  https://prometheus-community.github.io/helm-charts \
  >/dev/null 2>&1 || true

helm repo update

kubectl create namespace observability \
  --dry-run=client \
  -o yaml \
  | kubectl apply -f -

helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace observability \
  -f observability/values/kube-prometheus-stack-values.yaml

# Do NOT apply dashboard-provider.yaml directly.
# It is Grafana provisioning configuration, not a Kubernetes resource.

kubectl apply \
  -f observability/provisioning/grafana-dashboard-application-overview-configmap.yaml

kubectl apply \
  -f observability/provisioning/grafana-dashboard-jenkins-delivery-configmap.yaml

kubectl apply \
  -f observability/provisioning/grafana-dashboard-kubernetes-cluster-configmap.yaml

kubectl apply -f observability/monitors/
kubectl apply -f observability/rules/
kubectl apply -f observability/network-policies/

echo
echo "Waiting for observability workloads..."

kubectl rollout status \
  deployment/kube-prometheus-stack-operator \
  -n observability \
  --timeout=5m

kubectl rollout status \
  deployment/kube-prometheus-stack-grafana \
  -n observability \
  --timeout=5m

# ------------------------------------------------------------
# Verification
# ------------------------------------------------------------

section "FINAL PLATFORM VERIFICATION"

echo "===== NODES ====="
kubectl get nodes

echo
echo "===== JENKINS ====="
kubectl get pods -n jenkins
kubectl get pvc -n jenkins

echo
echo "===== OBSERVABILITY ====="
kubectl get pods -n observability
kubectl get pvc -n observability

echo
echo "===== SERVICE MONITORS ====="
kubectl get servicemonitors -n observability

echo
echo "===== PROMETHEUS RULES ====="
kubectl get prometheusrules -n observability | grep -E 'NAME|task5-alerts'

echo
echo "===== HELM ====="
helm list -n jenkins
helm list -n observability

echo
echo "===== APPLICATION ====="
kubectl get deployments,pods,svc -n devops-app 2>/dev/null || true

# ------------------------------------------------------------
# Demo access
# ------------------------------------------------------------

if [[ "${SKIP_DEMO}" == false ]]; then
  section "DEMO ENVIRONMENT"

  bash scripts/demo/start-demo.sh
else
  section "DEMO ENVIRONMENT SKIPPED"
fi

section "BOOTSTRAP COMPLETE"

cat <<'EOF'

Platform bootstrap completed successfully.

AWS / EKS       : ready
Jenkins         : ready
Observability   : ready

The application CI/CD is intentionally NOT triggered by this script.

To trigger the real delivery flow:
  1. Commit a change.
  2. Push to task5.
  3. GitHub webhook triggers Jenkins CI.
  4. Successful CI triggers CD.
  5. CD deploys the immutable images and runs the monitoring gate.

Useful URLs when demo mode is running:
  Jenkins:    http://127.0.0.1:8080
  Prometheus: http://127.0.0.1:9090
  Grafana:    http://127.0.0.1:3000

EOF