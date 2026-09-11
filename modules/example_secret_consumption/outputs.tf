# Output the DB endpoint for consumption by other modules or applications.
output "db_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = aws_db_instance.example_rds.endpoint
}

# Example of securely passing the database password to another module.
# The sensitive attribute prevents Terraform from displaying the value in the CLI output.
output "db_password" {
  description = "The database password retrieved from Secrets Manager."
  value       = data.aws_secretsmanager_secret_version.db_password.secret_string
  sensitive   = true
}

# Output the parameter store ARN for the API token
output "api_token_ssm_arn" {
  description = "The ARN of the SSM Parameter storing the API token"
  value       = aws_ssm_parameter.api_token_param.arn
}
