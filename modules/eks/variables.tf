variable "project_name" {
  description = "Project name used for EKS resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used by the EKS cluster and worker nodes"
  type        = list(string)
}
