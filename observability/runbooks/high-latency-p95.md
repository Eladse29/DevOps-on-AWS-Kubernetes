# HighLatencyP95 Runbook

## Trigger
Application p95 latency is above 1 second for at least 5 minutes.

## Check
1. Open the Application Overview dashboard.
2. Compare p50, p95 and p99 latency.
3. Identify the affected service and release.
4. Check CPU, memory and throttling.
5. Check dependency failures and Backend logs.

## Recovery
Restore the unhealthy dependency, increase required capacity if justified, or roll back the release if latency regression followed deployment.

## Verification
Confirm p95 latency returns below the SLO threshold and the alert resolves.
