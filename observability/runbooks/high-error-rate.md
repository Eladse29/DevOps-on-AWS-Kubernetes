# HighErrorRate Runbook

## Trigger
Application 5xx ratio is above 5% for at least 5 minutes.

## Check
1. Open the Application Overview dashboard.
2. Check the 5xx rate and affected release.
3. Check `app_dependency_failures_total` for RDS, Worker, S3 or SNS failures.
4. Inspect Backend Pod logs.
5. Compare the current release with the last known healthy release.

## Recovery
If the issue started immediately after deployment, roll back to the previous healthy Helm revision.
If the issue is caused by a dependency, restore that dependency and verify recovery.

## Verification
Confirm the 5xx ratio returns below the threshold and the alert becomes resolved.
