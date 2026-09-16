variable "db_password_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret containing the database password. This is a blind reference provided by the agent."
  type        = string
}

variable "api_token_vault_path" {
  description = "Path to the HashiCorp Vault secret containing the API token. This is a blind reference."
  type        = string
}

variable "db_instance_class" {
  description = "The instance type of the RDS instance."
  type        = string
  default     = "db.t3.micro"
}

variable "app_name" {
  description = "The name of the application."
  type        = string
}
