#!/usr/bin/env bash

set -euo pipefail

TRIVY_VERSION="${TRIVY_VERSION:-0.70.0}"
TRIVY_IMAGE="${TRIVY_IMAGE:-aquasec/trivy:${TRIVY_VERSION}}"
FAIL_ON_CRITICAL="${FAIL_ON_CRITICAL:-false}"

OUTPUT_DIRECTORY="${OUTPUT_DIRECTORY:-evidence/task5/security/platform-images}"
CACHE_DIRECTORY="${CACHE_DIRECTORY:-/tmp/trivy-cache-task5}"

images=(
  "jenkins/jenkins:2.568.1-jdk21"
  "jenkins/inbound-agent:3384.v60d89463d9e0-1-jdk21"
  "python:3.14.6-slim"
  "amazon/aws-cli:2.36.8"
  "gcr.io/kaniko-project/executor:v1.23.2-debug"
  "alpine/helm:3.21.0"
  "bitnami/kubectl:1.35.0"
  "curlimages/curl:8.16.0"
  "kiwigrid/k8s-sidecar:2.10.0"
)

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: Docker is required for the platform image scan." >&2
  exit 1
fi

mkdir -p "${OUTPUT_DIRECTORY}" "${CACHE_DIRECTORY}"

summary_file="${OUTPUT_DIRECTORY}/summary.txt"
: > "${summary_file}"

total_critical=0
total_high=0

echo "Trivy image: ${TRIVY_IMAGE}" | tee -a "${summary_file}"
echo | tee -a "${summary_file}"

for image in "${images[@]}"; do
  safe_name="$(
    printf '%s' "${image}" |
      tr '/:@' '---' |
      tr -cd 'a-zA-Z0-9._-'
  )"

  json_output="${OUTPUT_DIRECTORY}/${safe_name}.json"
  table_output="${OUTPUT_DIRECTORY}/${safe_name}.txt"

  echo "Scanning ${image}..."

  docker run --rm \
    --volume "${CACHE_DIRECTORY}:/root/.cache/" \
    "${TRIVY_IMAGE}" \
    image \
    --scanners vuln \
    --severity HIGH,CRITICAL \
    --ignore-unfixed \
    --format json \
    --output /dev/stdout \
    "${image}" \
    > "${json_output}"

  docker run --rm \
    --volume "${CACHE_DIRECTORY}:/root/.cache/" \
    "${TRIVY_IMAGE}" \
    image \
    --scanners vuln \
    --severity HIGH,CRITICAL \
    --ignore-unfixed \
    --format table \
    "${image}" \
    | tee "${table_output}"

  read -r critical_count high_count < <(
    python3 - "${json_output}" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
document = json.loads(path.read_text(encoding="utf-8"))

critical = 0
high = 0

for result in document.get("Results") or []:
    for vulnerability in result.get("Vulnerabilities") or []:
        severity = vulnerability.get("Severity")

        if severity == "CRITICAL":
            critical += 1
        elif severity == "HIGH":
            high += 1

print(critical, high)
PY
  )

  total_critical=$((total_critical + critical_count))
  total_high=$((total_high + high_count))

  printf '%-65s CRITICAL=%-4s HIGH=%-4s\n' \
    "${image}" \
    "${critical_count}" \
    "${high_count}" \
    | tee -a "${summary_file}"
done

{
  echo
  echo "Total CRITICAL findings: ${total_critical}"
  echo "Total HIGH findings: ${total_high}"
} | tee -a "${summary_file}"

if [[ "${FAIL_ON_CRITICAL}" == "true" && "${total_critical}" -gt 0 ]]; then
  echo "ERROR: Critical vulnerabilities were found." >&2
  exit 1
fi

echo
echo "Platform image scan completed."
echo "Results: ${OUTPUT_DIRECTORY}"
