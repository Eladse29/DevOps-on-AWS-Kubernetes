#!/usr/bin/env bash

set -euo pipefail

GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-Eladse29/DevOps-on-AWS-Kubernetes}"

JENKINS_NAMESPACE="${JENKINS_NAMESPACE:-jenkins}"
JENKINS_SERVICE="${JENKINS_SERVICE:-jenkins}"
LOCAL_JENKINS_PORT="${LOCAL_JENKINS_PORT:-18080}"

NGROK_API_URL="${NGROK_API_URL:-http://127.0.0.1:4040/api/tunnels}"
NGROK_POLICY_FILE="${NGROK_POLICY_FILE:-jenkins/ngrok-webhook-policy.yaml}"

EVIDENCE_DIRECTORY="${EVIDENCE_DIRECTORY:-evidence/task5/jenkins}"

PORT_FORWARD_PID=""
NGROK_PID=""

cleanup() {
  echo
  echo "Stopping the Jenkins webhook tunnel..."

  if [[ -n "${NGROK_PID}" ]] &&
     kill -0 "${NGROK_PID}" >/dev/null 2>&1
  then
    kill "${NGROK_PID}" >/dev/null 2>&1 || true
    wait "${NGROK_PID}" 2>/dev/null || true
  fi

  if [[ -n "${PORT_FORWARD_PID}" ]] &&
     kill -0 "${PORT_FORWARD_PID}" >/dev/null 2>&1
  then
    kill "${PORT_FORWARD_PID}" >/dev/null 2>&1 || true
    wait "${PORT_FORWARD_PID}" 2>/dev/null || true
  fi

  echo "Webhook tunnel stopped."
}

trap cleanup EXIT INT TERM

for required_command in \
  gh \
  kubectl \
  ngrok \
  curl \
  python3
do
  if ! command -v "${required_command}" >/dev/null 2>&1; then
    echo "ERROR: Required command was not found: ${required_command}" >&2
    exit 1
  fi
done

if [[ ! -f "${NGROK_POLICY_FILE}" ]]; then
  echo "ERROR: ngrok policy file was not found:" >&2
  echo "${NGROK_POLICY_FILE}" >&2
  exit 1
fi

echo "Checking GitHub authentication..."

gh auth status >/dev/null

echo "Checking ngrok configuration..."

ngrok config check >/dev/null

echo "Checking the Jenkins Kubernetes Service..."

kubectl get service "${JENKINS_SERVICE}" \
  --namespace "${JENKINS_NAMESPACE}" \
  >/dev/null

mkdir -p "${EVIDENCE_DIRECTORY}"

echo "Starting Jenkins port-forward on localhost:${LOCAL_JENKINS_PORT}..."

kubectl port-forward \
  "service/${JENKINS_SERVICE}" \
  "${LOCAL_JENKINS_PORT}:8080" \
  --namespace "${JENKINS_NAMESPACE}" \
  > "${EVIDENCE_DIRECTORY}/port-forward.log" 2>&1 &

PORT_FORWARD_PID=$!

for attempt in $(seq 1 30); do
  if curl \
    --silent \
    --fail \
    "http://127.0.0.1:${LOCAL_JENKINS_PORT}/login" \
    >/dev/null
  then
    echo "Jenkins port-forward is ready."
    break
  fi

  if ! kill -0 "${PORT_FORWARD_PID}" >/dev/null 2>&1; then
    echo "ERROR: kubectl port-forward stopped unexpectedly." >&2
    cat "${EVIDENCE_DIRECTORY}/port-forward.log" >&2
    exit 1
  fi

  if [[ "${attempt}" -eq 30 ]]; then
    echo "ERROR: Jenkins did not become reachable." >&2
    exit 1
  fi

  sleep 2
done

echo "Starting the protected ngrok HTTPS tunnel..."

ngrok http "${LOCAL_JENKINS_PORT}" \
  --traffic-policy-file "${NGROK_POLICY_FILE}" \
  --log "${EVIDENCE_DIRECTORY}/ngrok.log" \
  --log-format json \
  > /dev/null 2>&1 &

NGROK_PID=$!

PUBLIC_URL=""

for attempt in $(seq 1 30); do
  if ! kill -0 "${NGROK_PID}" >/dev/null 2>&1; then
    echo "ERROR: ngrok stopped unexpectedly." >&2
    cat "${EVIDENCE_DIRECTORY}/ngrok.log" >&2
    exit 1
  fi

  PUBLIC_URL="$(
    curl --silent --fail "${NGROK_API_URL}" 2>/dev/null |
      python3 -c '
import json
import sys

try:
    response = json.load(sys.stdin)

    https_tunnels = [
        tunnel["public_url"]
        for tunnel in response.get("tunnels", [])
        if tunnel.get("proto") == "https"
    ]

    if https_tunnels:
        print(https_tunnels[0])
except Exception:
    pass
' || true
  )"

  if [[ -n "${PUBLIC_URL}" ]]; then
    break
  fi

  if [[ "${attempt}" -eq 30 ]]; then
    echo "ERROR: Could not obtain the ngrok HTTPS URL." >&2
    exit 1
  fi

  sleep 2
done

WEBHOOK_URL="${PUBLIC_URL}/github-webhook/"

echo "Searching for an existing repository webhook..."

EXISTING_HOOK_ID="$(
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

if [[ -n "${EXISTING_HOOK_ID}" ]]; then
  echo "Updating existing GitHub webhook: ${EXISTING_HOOK_ID}"

  gh api \
    --method PATCH \
    "repos/${GITHUB_REPOSITORY}/hooks/${EXISTING_HOOK_ID}" \
    -F active=true \
    -f 'events[]=push' \
    -f "config[url]=${WEBHOOK_URL}" \
    -f 'config[content_type]=json' \
    -f 'config[insecure_ssl]=0' \
    >/dev/null
else
  echo "Creating the GitHub push webhook..."

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
fi

printf '%s\n' "${WEBHOOK_URL}" \
  > "${EVIDENCE_DIRECTORY}/webhook-url.txt"

echo
echo "============================================================"
echo "Jenkins webhook tunnel is ready"
echo "============================================================"
echo
echo "GitHub repository:"
echo "${GITHUB_REPOSITORY}"
echo
echo "Webhook URL:"
echo "${WEBHOOK_URL}"
echo
echo "Security:"
echo "Only POST /github-webhook/ is exposed through ngrok."
echo "The Jenkins UI is not exposed through this public endpoint."
echo
echo "Push a commit to the task5 branch to trigger application-ci."
echo
echo "Keep this terminal open during the webhook demonstration."
echo "Press Ctrl+C after the CI/CD demonstration is complete."
echo "============================================================"

wait "${NGROK_PID}"
