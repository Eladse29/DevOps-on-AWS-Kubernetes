# JenkinsQueueStuck Runbook

## Trigger
One or more Jenkins jobs remain queued for at least 5 minutes.

## Check
1. Open the Jenkins & Delivery dashboard.
2. Inspect Jenkins queue and dynamic agent metrics.
3. Check Pods in the `jenkins` namespace.
4. Describe any Pending CI, build or CD agent Pod.
5. Inspect Kubernetes scheduling events and resource availability.

## Recovery
Resolve the scheduling, resource or agent connectivity problem. Do not bypass Jenkins RBAC or grant cluster-admin.

## Verification
Confirm the queued job receives an agent, the queue clears and the alert resolves.
