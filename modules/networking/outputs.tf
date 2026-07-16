output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "First public subnet ID"
  value       = aws_subnet.public.id
}

output "public_subnet_2_id" {
  description = "Second public subnet ID"
  value       = aws_subnet.public_2.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = [aws_subnet.public.id, aws_subnet.public_2.id]
}

output "private_subnet_id" {
  description = "First private subnet ID"
  value       = aws_subnet.private.id
}

output "private_subnet_2_id" {
  description = "Second private subnet ID"
  value       = aws_subnet.private_2.id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = [aws_subnet.private.id, aws_subnet.private_2.id]
}
