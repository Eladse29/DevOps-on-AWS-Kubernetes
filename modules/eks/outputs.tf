output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster certificate authority data"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "EKS cluster OIDC issuer URL"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "node_group_name" {
  description = "EKS managed node group name"
  value       = aws_eks_node_group.main.node_group_name
}

output "cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN of the EKS IAM OIDC provider"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "ebs_csi_addon_name" {
  description = "Name of the Amazon EBS CSI EKS add-on"
  value       = aws_eks_addon.ebs_csi.addon_name
}

output "ebs_csi_role_arn" {
  description = "IAM role ARN used by the Amazon EBS CSI controller"
  value       = aws_iam_role.ebs_csi.arn
}