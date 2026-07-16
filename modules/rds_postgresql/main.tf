# This module creates a PostgreSQL RDS instance and subnet group
# used by the backend service to store application data.

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-subnet-group"
    Environment = var.environment
  }
}

resource "aws_db_instance" "postgres" {
  identifier             = "${var.project_name}-${var.environment}-postgres"
  engine                 = "postgres"
  engine_version         = "16.3"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  port                   = 5432
  vpc_security_group_ids = [var.rds_sg_id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  publicly_accessible = false
  skip_final_snapshot = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-postgres"
    Environment = var.environment
  }
}