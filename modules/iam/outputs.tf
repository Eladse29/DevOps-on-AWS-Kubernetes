output "backend_role_arn" {
  description = "IAM role ARN used by the backend Kubernetes ServiceAccount through IRSA"
  value       = aws_iam_role.backend_role.arn
}
