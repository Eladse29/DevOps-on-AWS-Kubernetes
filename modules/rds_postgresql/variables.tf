variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "subnet_ids" {
  description = "Subnet IDs for RDS subnet group"
  type        = list(string)
}

variable "rds_sg_id" {
  description = "Security group ID for RDS"
  type        = string
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}