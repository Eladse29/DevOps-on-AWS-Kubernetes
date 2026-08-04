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

variable "kubernetes_version" {
  description = "Pinned Kubernetes minor version for the EKS cluster"
  type        = string
}

variable "ebs_csi_addon_version" {
  description = "Pinned version of the Amazon EBS CSI EKS add-on"
  type        = string
}