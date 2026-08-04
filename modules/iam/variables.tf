variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "bucket_arn" {
  description = "S3 bucket ARN"
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic ARN"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS IAM OIDC provider"
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL of the EKS cluster"
  type        = string
}

variable "backend_namespace" {
  description = "Kubernetes namespace used by the backend service"
  type        = string
  default     = "devops-app"
}

variable "backend_service_account_name" {
  description = "Kubernetes ServiceAccount name used by the backend"
  type        = string
  default     = "backend-sa"
}
