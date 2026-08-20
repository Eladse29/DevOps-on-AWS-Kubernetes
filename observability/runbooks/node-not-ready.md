# NodeNotReady Runbook

## Trigger
A Kubernetes worker node is not Ready for at least 5 minutes.

## Check
1. Run `kubectl get nodes`.
2. Run `kubectl describe node <node>`.
3. Check node CPU, memory, disk and pressure conditions.
4. Verify whether application Pods were rescheduled to healthy nodes.

## Recovery
Restore or replace the unhealthy node using the EKS managed node group.

## Verification
Confirm all required nodes are Ready and application replicas are available.
