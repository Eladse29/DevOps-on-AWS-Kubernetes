# Task 4 Evidence Checklist

Final successful CI/CD evidence is anchored to repository revision `199763a`, CI build #5, and CD build #3.

Intentional CI failure and rollback evidence are explicitly identified test scenarios performed in the same Task 4 environment to demonstrate failure handling and recovery behavior.

## Jenkins
- 01-jenkins-namespaces.png
- 02-jenkins-controller.png
- 03-jenkins-service-pvc.png
- 04-jenkins-rbac.png
- 05-jenkins-helm-release.png
- 06-jenkins-jobs.png

## CI
- 07-ci-triggered-by-github.png
- 08-ci-validation-lint-tests.png
- 09-ci-kaniko-build.png
- 10-ci-trivy-scan.png
- 11-ci-ecr-digests.png
- 12-ci-success.png
- 13-ci-agent-running.png
- 14-ci-agent-removed.png
- 15-ci-intentional-failure.png
- 16-ci-failure-no-cd.png

## CD
- 17-cd-parameters-traceability.png
- 18-cd-helm-validation.png
- 19-cd-deploy.png
- 20-cd-rollout.png
- 21-cd-digest-verification.png
- 22-cd-smoke-test.png
- 23-cd-success.png

## Runtime / rollback
- 24-application-pods-services.png
- 25-helm-releases-history.png
- 26-rollback-proof.png
