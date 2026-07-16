resource "aws_ecr_repository" "frontend" {
  name         = "devops-frontend"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Service     = "frontend"
  }
}

resource "aws_ecr_repository" "backend" {
  name         = "devops-backend"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Service     = "backend"
  }
}

resource "aws_ecr_repository" "worker" {
  name         = "devops-worker"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Service     = "worker"
  }
}
