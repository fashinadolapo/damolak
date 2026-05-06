output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "app_public_ip" {
  description = "Public IP of the application EC2 instance"
  value       = module.ec2_app.public_ip
}

output "app_public_dns" {
  description = "Public DNS of the application EC2 instance"
  value       = module.ec2_app.public_dns
}

output "app_url" {
  description = "Application URL"
  value       = "http://${module.ec2_app.public_dns}:${var.app_port}"
}

output "health_check_url" {
  description = "Application health-check URL"
  value       = "http://${module.ec2_app.public_dns}:${var.app_port}/health"
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.ecr.repository_url
}

output "cloudwatch_log_group_app" {
  description = "CloudWatch log group for the application"
  value       = module.cloudwatch.app_log_group_name
}

output "github_actions_role_arn" {
  description = "IAM Role ARN — add this as AWS_OIDC_ROLE_ARN in GitHub Secrets"
  value       = module.iam.github_actions_role_arn
}
