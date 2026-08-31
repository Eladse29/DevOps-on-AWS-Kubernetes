#!/bin/sh
set -eu

PROM_URL="${PROM_URL:-http://kube-prometheus-stack-prometheus.observability.svc.cluster.local:9090}"

echo "Checking Prometheus application targets..."

for query in \
  'up{service="backend-service"}' \
  'up{service="worker-service"}' \
  'up{service="frontend-service"}'
do
  result="$(
    curl --fail --silent --show-error \
      --get \
      --data-urlencode "query=${query}" \
      "${PROM_URL}/api/v1/query"
  )"

  echo "${result}" | grep -q '"status":"success"'

  if ! echo "${result}" | grep -q '"value":\[[^]]*,"1"\]'; then
    echo "ERROR: Prometheus target is not UP for query: ${query}" >&2
    echo "${result}" >&2
    exit 1
  fi
done

echo "Checking application error rate..."

error_result="$(
  curl --fail --silent --show-error \
    --get \
    --data-urlencode 'query=(sum(rate(app_http_requests_total{status=~"5.."}[5m])) / clamp_min(sum(rate(app_http_requests_total[5m])), 0.000001))' \
    "${PROM_URL}/api/v1/query"
)"

error_value="$(
  echo "${error_result}" \
  | sed -n 's/.*"value":\[[^,]*,"\([^"]*\)"\].*/\1/p'
)"

if [ -n "${error_value}" ]; then
  awk -v v="${error_value}" 'BEGIN { if (v >= 0.05) exit 1 }' || {
    echo "ERROR: Application error rate is above 5%: ${error_value}" >&2
    exit 1
  }
fi

echo "Checking application p95 latency..."

latency_result="$(
  curl --fail --silent --show-error \
    --get \
    --data-urlencode 'query=histogram_quantile(0.95, sum by (le) (rate(app_http_request_duration_seconds_bucket[5m])))' \
    "${PROM_URL}/api/v1/query"
)"

latency_value="$(
  echo "${latency_result}" \
  | sed -n 's/.*"value":\[[^,]*,"\([^"]*\)"\].*/\1/p'
)"

if [ -n "${latency_value}" ]; then
  awk -v v="${latency_value}" 'BEGIN { if (v >= 1) exit 1 }' || {
    echo "ERROR: Application p95 latency is above 1 second: ${latency_value}" >&2
    exit 1
  }
fi

{
  echo "PROMETHEUS_URL=${PROM_URL}"
  echo "ERROR_RATE=${error_value:-no-data}"
  echo "P95_LATENCY_SECONDS=${latency_value:-no-data}"
  echo "MONITORING_GATE=PASSED"
} | tee monitoring-gate.txt

echo "Post-deploy monitoring gate passed."
