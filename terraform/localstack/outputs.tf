# Output values for LocalStack infrastructure

output "test_bucket_name" {
  description = "Name of the test S3 bucket"
  value       = aws_s3_bucket.test_bucket.id
}

output "test_security_group_id" {
  description = "ID of the test security group"
  value       = aws_security_group.test_sg.id
}

output "test_iam_role_arn" {
  description = "ARN of the test IAM role"
  value       = aws_iam_role.test_role.arn
}

output "environment" {
  description = "Current environment"
  value       = var.environment
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}
