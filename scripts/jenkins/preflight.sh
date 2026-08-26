#!/usr/bin/env bash

set -euo pipefail

EXPECTED_BRANCH="${EXPECTED_BRANCH:-task5}"
AWS_REGION="${AWS_REGION:-us-east-1}"
JENKINS_CHART_VERSION="${JENKINS_CHART_VERSION:-5.9.49}"
PYTHON_VENV="${PYTHON_VENV:-${HOME}/.venvs/devops-task5}"

BACKEND_VALUES_FILE="${BACKEND_VALUES_FILE:-helm/backend/values.local.yaml}"
JENKINS_RENDERED_FILE="${JENKINS_RENDERED_FILE:-/tmp/jenkins-rendered.yaml}"
JENKINS_CHART_DIRECTORY="${JENKINS_CHART_DIRECTORY:-/tmp/jenkins-chart}"

required_commands=(
  aws
  envsubst
  git
  gh
  helm
  kubectl
  python3
  terraform
)

required_files=(
  Jenkinsfile-ci
  Jenkinsfile-cd
  terraform.tfvars
  "${BACKEND_VALUES_FILE}"
  jenkins/values.yaml
  jenkins/values.example.yaml
  jenkins/jcasc/jenkins.yaml
  jenkins/jobs/jobs.groovy
  jenkins/agents/ci-agent.yaml
  jenkins/agents/build-agent.yaml
  jenkins/agents/cd-agent.yaml
  jenkins/rbac/ci-rbac.yaml
  jenkins/rbac/cd-rbac.yaml
  jenkins/storage/storageclass.yaml
  scripts/jenkins/install-jenkins.sh
  scripts/jenkins/configure-jenkins.sh
  scripts/jenkins/configure-webhook.sh
  scripts/jenkins/scan-platform-images.sh
  tests/backend/test_app.py
  tests/worker/test_worker.py
  tests/requirements.txt
)

echo "Task 5 preflight"
echo "================"

current_branch="$(git branch --show-current)"

if [[ "${current_branch}" != "${EXPECTED_BRANCH}" ]]; then
  echo "ERROR: Expected Git branch ${EXPECTED_BRANCH}, found ${current_branch}." >&2
  exit 1
fi

echo "Git branch: ${current_branch}"

for command_name in "${required_commands[@]}"; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "ERROR: Required command was not found: ${command_name}" >&2
    exit 1
  fi
done

for required_file in "${required_files[@]}"; do
  if [[ ! -f "${required_file}" ]]; then
    echo "ERROR: Required file was not found: ${required_file}" >&2
    exit 1
  fi
done

echo "Required commands and files: OK"

if ! grep -q \
  "def repositoryBranch = '\\*/task5'" \
  jenkins/jobs/jobs.groovy
then
  echo "ERROR: Jenkins jobs do not point to the task5 branch." >&2
  exit 1
fi

if ! grep -qE \
  '^[[:space:]]*dbPassword:[[:space:]]*"[^"]+"' \
  "${BACKEND_VALUES_FILE}"
then
  echo "ERROR: Backend dbPassword is missing or empty." >&2
  exit 1
fi

echo "Local backend values: OK"

if git ls-files | grep -E \
  '(^|/)(\.env|terraform\.tfstate|terraform\.tfstate\.backup|terraform\.tfvars|values\.local\.yaml|secrets\.yml|inventory\.ini)$'
then
  echo "ERROR: Sensitive local files are tracked by Git." >&2
  exit 1
fi

if git grep -nE \
  'AWS_SECRET_ACCESS_KEY[[:space:]]*=|AWS_ACCESS_KEY_ID[[:space:]]*=|BEGIN (RSA |OPENSSH )?PRIVATE KEY'
then
  echo "ERROR: A possible credential was found in tracked files." >&2
  exit 1
fi

echo "Git secret checks: OK"

if grep -RInE \
  '^[[:space:]]*image:[[:space:]]+[^[:space:]]+:latest[[:space:]]*$|^[[:space:]]*tag:[[:space:]]*latest[[:space:]]*$|^[[:space:]]*privileged:[[:space:]]*true[[:space:]]*$|^[[:space:]]*mountPath:[[:space:]]*/var/run/docker.sock[[:space:]]*$|^[[:space:]]*name:[[:space:]]*cluster-admin[[:space:]]*$' \
  jenkins
then
  echo "ERROR: Forbidden image or privilege configuration was found." >&2
  exit 1
fi

echo "Security pattern checks: OK"

for script in scripts/jenkins/*.sh; do
  bash -n "${script}"
done

echo "Bash syntax: OK"

git diff --check

echo "Git whitespace check: OK"

terraform fmt -check -recursive
terraform validate

echo "Terraform formatting and validation: OK"

rm -f tfplan

terraform plan \
  -out=tfplan

echo "Terraform plan: OK"

for chart in frontend backend worker; do
  helm lint "helm/${chart}"
done

echo "Application Helm charts: OK"

helm template jenkins jenkins/jenkins \
  --version "${JENKINS_CHART_VERSION}" \
  --namespace jenkins \
  --values jenkins/values.yaml \
  --set-file agent.podTemplates.ci=jenkins/agents/ci-agent.yaml \
  --set-file agent.podTemplates.build=jenkins/agents/build-agent.yaml \
  --set-file agent.podTemplates.cd=jenkins/agents/cd-agent.yaml \
  > "${JENKINS_RENDERED_FILE}"

grep -q 'allowAnonymousRead: false' "${JENKINS_RENDERED_FILE}"
grep -q 'allowsSignup: false' "${JENKINS_RENDERED_FILE}"
grep -q 'numExecutors: 0' "${JENKINS_RENDERED_FILE}"
grep -q 'label: jenkins-ci' "${JENKINS_RENDERED_FILE}"
grep -q 'label: jenkins-build' "${JENKINS_RENDERED_FILE}"
grep -q 'label: jenkins-cd' "${JENKINS_RENDERED_FILE}"
grep -q 'storageClassName: "jenkins-ebs"' "${JENKINS_RENDERED_FILE}"

echo "Jenkins Helm render: OK"

rm -rf "${JENKINS_CHART_DIRECTORY}"

helm pull jenkins/jenkins \
  --version "${JENKINS_CHART_VERSION}" \
  --untar \
  --untardir "${JENKINS_CHART_DIRECTORY}"

helm lint "${JENKINS_CHART_DIRECTORY}/jenkins" \
  --namespace jenkins \
  --values jenkins/values.yaml

echo "Jenkins Helm lint: OK"

if [[ ! -x "${PYTHON_VENV}/bin/python" ]]; then
  echo "Creating Python virtual environment at ${PYTHON_VENV}..."
  mkdir -p "$(dirname "${PYTHON_VENV}")"
  python3 -m venv "${PYTHON_VENV}"
fi

"${PYTHON_VENV}/bin/python" -m pip install \
  --disable-pip-version-check \
  --quiet \
  -r docker/backend/requirements.txt \
  -r docker/worker/requirements.txt \
  -r tests/requirements.txt

"${PYTHON_VENV}/bin/python" -m flake8 \
  docker/backend/app.py \
  docker/worker/worker.py \
  tests/backend/test_app.py \
  tests/worker/test_worker.py \
  --max-line-length=100

mkdir -p test-results

AWS_EC2_METADATA_DISABLED=true \
AWS_DEFAULT_REGION="${AWS_REGION}" \
AWS_REGION="${AWS_REGION}" \
"${PYTHON_VENV}/bin/python" -m pytest \
  tests/backend \
  tests/worker \
  --junitxml=test-results/pytest-results.xml \
  --cov=docker/backend \
  --cov=docker/worker \
  --cov-report=term-missing

echo "Python lint and tests: OK"

configured_region="$(aws configure get region)"

if [[ "${configured_region}" != "${AWS_REGION}" ]]; then
  echo "ERROR: AWS CLI region is ${configured_region}, expected ${AWS_REGION}." >&2
  exit 1
fi

aws_account_id="$(
  aws sts get-caller-identity \
    --query Account \
    --output text
)"

echo "AWS account: ${aws_account_id}"
echo "AWS region: ${configured_region}"

echo
echo "Terraform plan summary:"

terraform_summary="$(
  terraform show -no-color tfplan |
    grep -E 'Plan:|will be created' |
    tail -n 20 || true
)"

if [[ -n "${terraform_summary}" ]]; then
  printf '%s\n' "${terraform_summary}"
else
  echo "No infrastructure changes planned."
fi

echo
echo "Task 5 preflight completed successfully."

echo
echo "Preflight completed successfully."
echo "The saved Terraform plan is: tfplan"
