#!/usr/bin/env bash

set -euo pipefail

GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-Eladse29/DevOps-on-AWS-Kubernetes}"

STATE_DIR="${STATE_DIR:-/tmp/devops-project-demo}"
LOG_DIR="${STATE_DIR}/logs"

JENKINS_NAMESPACE="jenkins"
OBSERVABILITY_NAMESPACE="observability"

JENKINS_UI_PORT=8080
JENKINS_WEBHOOK_PORT=18080
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000

NGROK_API_URL="http://127.0.0.1:4040/api/tunnels"
NGROK_POLICY_FILE="jenkins/ngrok-webhook-policy.yaml"

mkdir -p "${STATE_DIR}" "${LOG_DIR}"

for command in kubectl curl gh ngrok python3; do
    if ! command -v "${command}" >/dev/null 2>&1; then
        echo "ERROR: Required command not found: ${command}" >&2
        exit 1
    fi
done

if [[ ! -f "${NGROK_POLICY_FILE}" ]]; then
    echo "ERROR: Missing ${NGROK_POLICY_FILE}" >&2
    exit 1
fi

echo "============================================================"
echo " DEVOPS PROJECT DEMO ENVIRONMENT"
echo "============================================================"

echo
echo "===== CLUSTER CHECK ====="

kubectl cluster-info >/dev/null
kubectl get nodes

echo
echo "===== REQUIRED SERVICES ====="

kubectl get svc jenkins -n "${JENKINS_NAMESPACE}" >/dev/null
kubectl get svc monitoring-kube-prometheus-prometheus \
    -n "${OBSERVABILITY_NAMESPACE}" >/dev/null
kubectl get svc monitoring-grafana \
    -n "${OBSERVABILITY_NAMESPACE}" >/dev/null

echo "Required services found."

start_port_forward() {
    local name="$1"
    local namespace="$2"
    local service="$3"
    local mapping="$4"

    local pid_file="${STATE_DIR}/${name}.pid"
    local log_file="${LOG_DIR}/${name}.log"

    if [[ -f "${pid_file}" ]]; then
        old_pid="$(cat "${pid_file}")"

        if kill -0 "${old_pid}" >/dev/null 2>&1; then
            echo "${name}: already running (PID ${old_pid})"
            return
        fi

        rm -f "${pid_file}"
    fi

    echo "Starting ${name}..."

    nohup kubectl port-forward \
        --namespace "${namespace}" \
        "service/${service}" \
        "${mapping}" \
        >"${log_file}" 2>&1 &

    echo $! > "${pid_file}"
}

wait_http() {
    local name="$1"
    local url="$2"
    local pid_file="$3"

    for attempt in $(seq 1 30); do
        if curl --silent --fail "${url}" >/dev/null 2>&1; then
            echo "${name}: READY"
            return 0
        fi

        if [[ -f "${pid_file}" ]]; then
            pid="$(cat "${pid_file}")"

            if ! kill -0 "${pid}" >/dev/null 2>&1; then
                echo "ERROR: ${name} process stopped." >&2
                exit 1
            fi
        fi

        sleep 2
    done

    echo "ERROR: ${name} did not become reachable." >&2
    exit 1
}

echo
echo "===== PORT FORWARDS ====="

start_port_forward \
    jenkins-ui \
    "${JENKINS_NAMESPACE}" \
    jenkins \
    "${JENKINS_UI_PORT}:8080"

start_port_forward \
    jenkins-webhook \
    "${JENKINS_NAMESPACE}" \
    jenkins \
    "${JENKINS_WEBHOOK_PORT}:8080"

start_port_forward \
    prometheus \
    "${OBSERVABILITY_NAMESPACE}" \
    monitoring-kube-prometheus-prometheus \
    "${PROMETHEUS_PORT}:9090"

start_port_forward \
    grafana \
    "${OBSERVABILITY_NAMESPACE}" \
    monitoring-grafana \
    "${GRAFANA_PORT}:80"

echo
echo "===== READINESS ====="

wait_http \
    "Jenkins" \
    "http://127.0.0.1:${JENKINS_UI_PORT}/login" \
    "${STATE_DIR}/jenkins-ui.pid"

wait_http \
    "Prometheus" \
    "http://127.0.0.1:${PROMETHEUS_PORT}/-/ready" \
    "${STATE_DIR}/prometheus.pid"

wait_http \
    "Grafana" \
    "http://127.0.0.1:${GRAFANA_PORT}/login" \
    "${STATE_DIR}/grafana.pid"

echo
echo "===== GITHUB / NGROK ====="

gh auth status >/dev/null
ngrok config check >/dev/null

if [[ -f "${STATE_DIR}/ngrok.pid" ]]; then
    old_pid="$(cat "${STATE_DIR}/ngrok.pid")"

    if kill -0 "${old_pid}" >/dev/null 2>&1; then
        echo "Stopping previous ngrok process..."
        kill "${old_pid}" >/dev/null 2>&1 || true
        sleep 2
    fi

    rm -f "${STATE_DIR}/ngrok.pid"
fi

nohup ngrok http "${JENKINS_WEBHOOK_PORT}" \
    --traffic-policy-file "${NGROK_POLICY_FILE}" \
    --log "${LOG_DIR}/ngrok.log" \
    --log-format json \
    >/dev/null 2>&1 &

echo $! > "${STATE_DIR}/ngrok.pid"

PUBLIC_URL=""

for attempt in $(seq 1 30); do
    PUBLIC_URL="$(
        curl --silent "${NGROK_API_URL}" 2>/dev/null |
        python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)

    for tunnel in data.get("tunnels", []):
        url = tunnel.get("public_url", "")
        if url.startswith("https://"):
            print(url)
            break
except Exception:
    pass
' || true
    )"

    if [[ -n "${PUBLIC_URL}" ]]; then
        break
    fi

    sleep 2
done

if [[ -z "${PUBLIC_URL}" ]]; then
    echo "ERROR: Could not obtain ngrok public URL." >&2
    exit 1
fi

WEBHOOK_URL="${PUBLIC_URL}/github-webhook/"

echo "ngrok: READY"
echo "Webhook URL: ${WEBHOOK_URL}"

echo
echo "===== UPDATE GITHUB WEBHOOK ====="

HOOK_ID="$(
    gh api \
        "repos/${GITHUB_REPOSITORY}/hooks" \
        --paginate \
        --jq '
            .[]
            | select(
                (.config.url | endswith("/github-webhook/"))
                or
                (.config.url | startswith("https://smee.io/"))
            )
            | .id
        ' |
        head -n 1
)"

if [[ -n "${HOOK_ID}" ]]; then
    gh api \
        --method PATCH \
        "repos/${GITHUB_REPOSITORY}/hooks/${HOOK_ID}" \
        -F active=true \
        -f 'events[]=push' \
        -f "config[url]=${WEBHOOK_URL}" \
        -f 'config[content_type]=json' \
        -f 'config[insecure_ssl]=0' \
        >/dev/null

    echo "GitHub webhook ${HOOK_ID}: UPDATED"
else
    gh api \
        --method POST \
        "repos/${GITHUB_REPOSITORY}/hooks" \
        -f name=web \
        -F active=true \
        -f 'events[]=push' \
        -f "config[url]=${WEBHOOK_URL}" \
        -f 'config[content_type]=json' \
        -f 'config[insecure_ssl]=0' \
        >/dev/null

    echo "GitHub webhook: CREATED"
fi

printf '%s\n' "${WEBHOOK_URL}" > "${STATE_DIR}/webhook-url.txt"

echo
echo "===== APPLICATION STATUS ====="

kubectl get deployments -n devops-app || true

echo
echo "============================================================"
echo " DEMO ENVIRONMENT READY"
echo "============================================================"
echo
echo "Jenkins:"
echo "  http://127.0.0.1:${JENKINS_UI_PORT}"
echo
echo "Prometheus:"
echo "  http://127.0.0.1:${PROMETHEUS_PORT}"
echo
echo "Grafana:"
echo "  http://127.0.0.1:${GRAFANA_PORT}"
echo
echo "GitHub webhook:"
echo "  ${WEBHOOK_URL}"
echo
echo "State/logs:"
echo "  ${STATE_DIR}"
echo
echo "Stop everything with:"
echo "  bash scripts/demo/stop-demo.sh"
echo
echo "============================================================"
