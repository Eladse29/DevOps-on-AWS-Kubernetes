module "networking" {
  source = "./modules/networking"

  project_name          = var.project_name
  environment           = var.environment
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidr    = var.public_subnet_cidr
  public_subnet_2_cidr  = var.public_subnet_2_cidr
  private_subnet_cidr   = var.private_subnet_cidr
  private_subnet_2_cidr = var.private_subnet_2_cidr
}

module "security_groups" {
  source = "./modules/security_groups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.networking.vpc_id
}

module "rds_postgresql" {
  source = "./modules/rds_postgresql"

  project_name = var.project_name
  environment  = var.environment

  subnet_ids = module.networking.private_subnet_ids
  rds_sg_id  = module.security_groups.rds_sg_id

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
}

module "s3_bucket" {
  source = "./modules/s3_bucket"

  bucket_name = var.bucket_name
  environment = var.environment
}

module "sns_topic" {
  source = "./modules/sns_topic"

  topic_name     = var.sns_topic_name
  email_endpoint = var.sns_email_endpoint
}

module "iam" {
  source = "./modules/iam"

  project_name      = var.project_name
  environment       = var.environment
  bucket_arn        = module.s3_bucket.bucket_arn
  sns_topic_arn     = module.sns_topic.topic_arn
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.cluster_oidc_issuer_url

  backend_namespace            = "devops-app"
  backend_service_account_name = "backend-sa"

  jenkins_namespace               = "jenkins"
  jenkins_ci_service_account_name = "jenkins-ci-agent"

  ecr_repository_arns = [
    module.ecr.frontend_repository_arn,
    module.ecr.backend_repository_arn,
    module.ecr.worker_repository_arn
  ]
}

module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

module "eks" {
  source = "./modules/eks"

  project_name          = var.project_name
  environment           = var.environment
  private_subnet_ids    = module.networking.private_subnet_ids
  kubernetes_version    = var.kubernetes_version
  ebs_csi_addon_version = var.ebs_csi_addon_version
}

resource "aws_security_group_rule" "rds_from_eks" {
  type                     = "ingress"
  description              = "PostgreSQL access from EKS cluster security group"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = module.security_groups.rds_sg_id
  source_security_group_id = module.eks.cluster_security_group_id
}
