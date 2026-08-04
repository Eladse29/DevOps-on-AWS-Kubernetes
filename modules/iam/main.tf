# -----------------------------------------------------------------------------
# Backend IRSA
# -----------------------------------------------------------------------------

resource "aws_iam_role" "backend_role" {
  name = "${var.project_name}-${var.environment}-backend-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
            "${replace(var.oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:${var.backend_namespace}:${var.backend_service_account_name}"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-backend-role"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_policy" "backend_policy" {
  name        = "${var.project_name}-${var.environment}-backend-policy"
  description = "Allows the backend to upload reports to S3 and publish SNS messages"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "UploadReportsToProjectBucket"
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${var.bucket_arn}/*"
      },
      {
        Sid    = "PublishProjectNotifications"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.sns_topic_arn
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-backend-policy"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "backend_attach" {
  role       = aws_iam_role.backend_role.name
  policy_arn = aws_iam_policy.backend_policy.arn
}

# -----------------------------------------------------------------------------
# Jenkins CI Agent IRSA
# -----------------------------------------------------------------------------

resource "aws_iam_role" "jenkins_ci_role" {
  name = "${var.project_name}-${var.environment}-jenkins-ci-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
            "${replace(var.oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:${var.jenkins_namespace}:${var.jenkins_ci_service_account_name}"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-jenkins-ci-role"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_policy" "jenkins_ci_ecr_policy" {
  name        = "${var.project_name}-${var.environment}-jenkins-ci-ecr-policy"
  description = "Allows the Jenkins CI agent to push and inspect images in project ECR repositories"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GetECRAuthorizationToken"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "PushAndInspectProjectImages"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:DescribeImageScanFindings",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:InitiateLayerUpload",
          "ecr:ListImages",
          "ecr:PutImage",
          "ecr:StartImageScan",
          "ecr:UploadLayerPart"
        ]
        Resource = var.ecr_repository_arns
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-jenkins-ci-ecr-policy"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "jenkins_ci_ecr_attach" {
  role       = aws_iam_role.jenkins_ci_role.name
  policy_arn = aws_iam_policy.jenkins_ci_ecr_policy.arn
}