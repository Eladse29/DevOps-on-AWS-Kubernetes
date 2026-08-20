# ReplicasMismatch Runbook

## Trigger
A devops-app Deployment has fewer available replicas than desired for at least 5 minutes.

## Check
1. Run `kubectl get deployments,pods -n devops-app`.
2. Describe unhealthy or Pending Pods.
3. Check scheduling events, readiness failures and resource limits.
4. Check the Kubernetes / Cluster dashboard.

## Recovery
Resolve the scheduling or readiness issue. Kubernetes should recreate failed Pods automatically.

## Verification
Confirm desired and available replicas match again and the alert resolves.
