# Task 5 - SLI and SLO

## Availability

### SLI
The percentage of application requests that do not return HTTP 5xx responses.

### PromQL

100 * (
  1 -
  (
    (sum(rate(app_http_requests_total{status=~"5.."}[5m])) or vector(0))
    /
    clamp_min(sum(rate(app_http_requests_total[5m])), 0.000001)
  )
)

### SLO
Availability must be at least 99%.

---

## Latency

### SLI
The p95 HTTP request latency measured from the application request-duration histogram.

### PromQL

histogram_quantile(
  0.95,
  sum by (le) (
    rate(app_http_request_duration_seconds_bucket[5m])
  )
)

### SLO
p95 latency must remain below 1 second.

---

## Release traceability

Application release information is exposed through:

app_info

The metric contains the service, version, git_sha and release labels.

---

## Dependency failures

Dependency failures can be diagnosed using:

sum by (dependency) (
  rate(app_dependency_failures_total[5m])
)

Dependencies include RDS, Worker, S3 and SNS.

---

## Business metric

The Backend exposes:

app_machines_created_total

This counter represents successful machine creation operations.

The Worker also exposes:

app_worker_process_total

for successful Worker process operations.
