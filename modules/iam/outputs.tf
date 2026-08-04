output "backend_role_arn" {
  description = "IAM role ARN used by the backend Kubernetes ServiceAccount"
  value       = aws_iam_role.backend_role.arn
}

output "jenkins_ci_role_arn" {
  description = "IAM role ARN used by the Jenkins CI agent ServiceAccount"
  value       = aws_iam_role.jenkins_ci_role.arn
}