output "rds_endpoint" {
  value = module.rds_postgresql.rds_endpoint
}

output "s3_bucket_name" {
  value = module.s3_bucket.bucket_name
}

output "sns_topic_arn" {
  value = module.sns_topic.topic_arn
}

output "frontend_ecr_repository_url" {
  value = module.ecr.frontend_repository_url
}

output "backend_ecr_repository_url" {
  value = module.ecr.backend_repository_url
}

output "worker_ecr_repository_url" {
  value = module.ecr.worker_repository_url
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_node_group_name" {
  value = module.eks.node_group_name
}

output "backend_irsa_role_arn" {
  value = module.iam.backend_role_arn
}

output "ebs_csi_addon_name" {
  value = module.eks.ebs_csi_addon_name
}

output "ebs_csi_role_arn" {
  value = module.eks.ebs_csi_role_arn
}

output "jenkins_ci_role_arn" {
  value = module.iam.jenkins_ci_role_arn
}