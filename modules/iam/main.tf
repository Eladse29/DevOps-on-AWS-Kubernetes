# IRSA role assumed only by the backend ServiceAccount in the devops-app namespace.
# This avoids storing static AWS credentials inside Kubernetes Secrets or container images.

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
}

# Least-privilege policy: the backend may only upload objects to the project
# S3 bucket and publish notifications to the project SNS topic.

resource "aws_iam_policy" "backend_policy" {
  name        = "${var.project_name}-${var.environment}-backend-policy"
  description = "Allows backend Kubernetes service to upload reports to S3 and publish SNS messages"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${var.bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.sns_topic_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backend_attach" {
  role       = aws_iam_role.backend_role.name
  policy_arn = aws_iam_policy.backend_policy.arn
}
