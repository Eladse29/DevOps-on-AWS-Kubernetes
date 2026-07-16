resource "aws_iam_role" "cluster" {
  name = "${var.project_name}-${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-${var.environment}-eks"
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy
  ]

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role" "nodes" {
  name = "${var.project_name}-${var.environment}-eks-nodes-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "nodes_worker_policy" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "nodes_ecr_policy" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role_policy_attachment" "nodes_cni_policy" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# Launch template used to apply consistent Name, Project and Environment
# tags to EC2 worker nodes and their EBS volumes.

resource "aws_launch_template" "eks_nodes" {
  name_prefix = "${var.project_name}-${var.environment}-eks-nodes-"

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "${var.project_name}-${var.environment}-worker-node"
      Project     = var.project_name
      Environment = var.environment
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name        = "${var.project_name}-${var.environment}-worker-node-volume"
      Project     = var.project_name
      Environment = var.environment
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-eks-node-template"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Three managed worker nodes provide compute capacity and high availability
# for the frontend, backend and worker Kubernetes workloads.

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-${var.environment}-node-group"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids
  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.latest_version
  }
  instance_types = ["t3.small"]

  scaling_config {
    desired_size = 3
    min_size     = 3
    max_size     = 3
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_worker_policy,
    aws_iam_role_policy_attachment.nodes_ecr_policy,
    aws_iam_role_policy_attachment.nodes_cni_policy
  ]

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint
  ]

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
