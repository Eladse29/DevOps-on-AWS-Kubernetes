#!/bin/sh
set -eu

PROM_URL="${PROM_URL:-http://kube-prometheus-stack-prometheus.observability.svc.cluster.local:9090}"

query_prometheus() {
  curl --fail --silent --show-error \
    --get \
    --data-urlencode "query=$1" \
    "${PROM_URL}/api/v1/query"
}

extract_scalar() {
  tr -d '\n' |
    sed -n 's/.*"value":[[:space:]]*\[[^,]*,[[:space:]]*"\([^"]*\)".*/\1/p'
}

echo "Checking Prometheus application targets..."

for service in backend-service worker-service frontend-service
do
  result="$(query_prometheus "min(up{service=\"${service}\"})")"
  value="$(printf '%s' "${result}" | extract_scalar)"

  if [ -z "${value}" ]; then
    echo "ERROR: No Prometheus target data for ${service}" >&2
    exit 1
  fi

  if [ "${value}" != "1" ]; then
    echo "ERROR: At least one Prometheus target is DOWN for ${service}" >&2
    exit 1
  fi

  echo "${service}: all targets UP"
done

echo "Checking application request metrics..."

metric_result="$(query_prometheus 'count(app_http_requests_total)')"
metric_count="$(printf '%s' "${metric_result}" | extract_scalar)"

if [ -z "${metric_count}" ] || [ "${metric_count}" = "0" ]; then
  echo "ERROR: app_http_requests_total is not available in Prometheus" >&2
  exit 1
fi

echo "app_http_requests_total: available (${metric_count} series)"

echo "Checking application error rate..."

error_result="$(
  query_prometheus '
(
  sum(rate(app_http_requests_total{status=~"5.."}[10m]))
  or vector(0)
)
/
clamp_min(
  (sum(rate(app_http_requests_total[10m])) or vector(0)),
  0.000001
)'
)"

error_value="$(printf '%s' "${error_result}" | extract_scalar)"

if [ -z "${error_value}" ]; then
  echo "ERROR: Could not evaluate application error rate" >&2
  exit 1
fi

awk -v v="${error_value}" 'BEGIN { if (v >= 0.05) exit 1 }' || {
  echo "ERROR: Application error rate is above 5%: ${error_value}" >&2
  exit 1
}

echo "Application error rate: ${error_value}"

echo "Checking application latency metrics..."

latency_metric_result="$(
  query_prometheus 'count(app_http_request_duration_seconds_bucket)'
)"
latency_metric_count="$(
  printf '%s' "${latency_metric_result}" | extract_scalar
)"

if [ -z "${latency_metric_count}" ] || [ "${latency_metric_count}" = "0" ]; then
  echo "ERROR: Application latency histogram is not available" >&2
  exit 1
fi

echo "Latency histogram: available (${latency_metric_count} series)"

echo "Checking application p95 latency..."

latency_result="$(
  query_prometheus '
histogram_quantile(
  0.95,
  sum by (le) (
    rate(app_http_request_duration_seconds_bucket[10m])
  )
)'
)"

latency_value="$(printf '%s' "${latency_result}" | extract_scalar)"

# A histogram can legitimately return NaN immediately after deployment
# when there have not yet been enough observations.
if [ -z "${latency_value}" ]; then
  echo "ERROR: Could not evaluate application p95 latency" >&2
  exit 1
fi

if [ "${latency_value}" = "NaN" ]; then
  echo "Application p95 latency: no observations in evaluation window"
else
  awk -v v="${latency_value}" 'BEGIN { if (v >= 1) exit 1 }' || {
    echo "ERROR: Application p95 latency is above 1 second: ${latency_value}" >&2
    exit 1
  }

  echo "Application p95 latency: ${latency_value} seconds"
fi

{
  echo "PROMETHEUS_URL=${PROM_URL}"
  echo "ERROR_RATE=${error_value}"
  echo "P95_LATENCY_SECONDS=${latency_value}"
  echo "MONITORING_GATE=PASSED"
} | tee monitoring-gate.txt

echo "Post-deploy monitoring gate passed."
