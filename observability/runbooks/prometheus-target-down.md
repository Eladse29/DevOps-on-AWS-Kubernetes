# PrometheusTargetDown Runbook

## Trigger
A Prometheus scrape target remains DOWN for at least 5 minutes.

## Check
1. Open Prometheus Targets.
2. Identify the failed target and scrape error.
3. Verify the target Service and Pod.
4. Verify ServiceMonitor selectors, port name and metrics path.
5. Check NetworkPolicy and namespace connectivity where applicable.

## Recovery
Restore the failed workload or correct the scrape discovery/connectivity configuration.

## Verification
Confirm the target returns to UP and the alert resolves.
