#!/usr/bin/env bash

set -euo pipefail

GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-Eladse29/DevOps-on-AWS-Kubernetes}"
JENKINS_NAMESPACE="${JENKINS_NAMESPACE:-jenkins}"
JENKINS_SERVICE="${JENKINS_SERVICE:-jenkins}"
LOCAL_JENKINS_PORT="${LOCAL_JENKINS_PORT:-18080}"
SMEE_CLIENT_VERSION="${SMEE_CLIENT_VERSION:-5.0.0}"

SMEE_URL="${SMEE_URL:-}"

if [[ -z "${SMEE_URL}" ]]; then
  echo "ERROR: SMEE_URL is required." >&2
  echo "Create a Smee channel and run:" >&2
  echo "export SMEE_URL=https://smee.io/YOUR_CHANNEL_ID" >&2
  exit 1
fi

case "${SMEE_URL}" in
  https://smee.io/*)
    ;;
  *)
    echo "ERROR: SMEE_URL must use https://smee.io/." >&2
    exit 1
    ;;
esac

for required_command in gh kubectl npx curl; do
  if ! command -v "${required_command}" >/dev/null 2>&1; then
    echo "ERROR: Required command was not found: ${required_command}" >&2
    exit 1
  fi
done

gh auth status >/dev/null

kubectl get service "${JENKINS_SERVICE}" \
  --namespace "${JENKINS_NAMESPACE}" >/dev/null

echo "Checking GitHub webhook configuration..."

existing_hook_id="$(
  gh api \
    "repos/${GITHUB_REPOSITORY}/hooks" \
    --paginate \
    --jq ".[] | select(.config.url == \"${SMEE_URL}\") | .id" |
    head -n 1
)"

if [[ -n "${existing_hook_id}" ]]; then
  echo "Updating existing GitHub webhook: ${existing_hook_id}"

  gh api \
    --method PATCH \
    "repos/${GITHUB_REPOSITORY}/hooks/${existing_hook_id}" \
    -F active=true \
    -f 'events[]=push' \
    -f "config[url]=${SMEE_URL}" \
    -f 'config[content_type]=json' \
    -f 'config[insecure_ssl]=0' \
    >/dev/null
else
  echo "Creating GitHub push webhook..."

  gh api \
    --method POST \
    "repos/${GITHUB_REPOSITORY}/hooks" \
    -f name=web \
    -F active=true \
    -f 'events[]=push' \
    -f "config[url]=${SMEE_URL}" \
    -f 'config[content_type]=json' \
    -f 'config[insecure_ssl]=0' \
    >/dev/null
fi

mkdir -p evidence/task4/jenkins

echo "Starting Jenkins port-forward on localhost:${LOCAL_JENKINS_PORT}..."

kubectl port-forward \
  "service/${JENKINS_SERVICE}" \
  "${LOCAL_JENKINS_PORT}:8080" \
  --namespace "${JENKINS_NAMESPACE}" \
  > evidence/task4/jenkins/port-forward.log 2>&1 &

port_forward_pid=$!

cleanup() {
  if kill -0 "${port_forward_pid}" >/dev/null 2>&1; then
    kill "${port_forward_pid}" >/dev/null 2>&1 || true
    wait "${port_forward_pid}" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

for attempt in $(seq 1 30); do
  if curl \
    --silent \
    --fail \
    "http://127.0.0.1:${LOCAL_JENKINS_PORT}/login" \
    >/dev/null
  then
    break
  fi

  if [[ "${attempt}" -eq 30 ]]; then
    echo "ERROR: Jenkins did not become reachable through port-forward." >&2
    exit 1
  fi

  sleep 2
done

echo "GitHub webhook URL: ${SMEE_URL}"
echo "Jenkins webhook target:"
echo "http://127.0.0.1:${LOCAL_JENKINS_PORT}/github-webhook/"
echo
echo "Keep this terminal open while demonstrating push-triggered CI."

npx --yes "smee-client@${SMEE_CLIENT_VERSION}" \
  --url "${SMEE_URL}" \
  --target "http://127.0.0.1:${LOCAL_JENKINS_PORT}/github-webhook/"