terraform {
  required_version = ">=1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.0"
    }
  }
}

# 1. Fetching the secret from AWS Secrets Manager using the ARN reference
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = var.db_password_secret_arn
}

# 2. Fetching the secret from Vault using the Vault path reference
data "vault_generic_secret" "api_token" {
  path = var.api_token_vault_path
}

# 3. Example: Provision an AWS RDS Database using the fetched secret securely
resource "aws_db_instance" "example_rds" {
  identifier        = "${var.app_name}-db"
  allocated_storage = 20
  engine            = "postgres"
  engine_version    = "15.3"
  instance_class    = var.db_instance_class
  username          = "admin"

  # Inject the secret value dynamically
  # Using jsondecode is common if the secret stores a JSON object rather than a raw string.
  password = data.aws_secretsmanager_secret_version.db_password.secret_string

  skip_final_snapshot = true

  # Ensure changes to this blind reference don't cause unintended recreations 
  # of sensitive assets unless intended. 
  lifecycle {
    ignore_changes = [password]
  }
}

# 4. Example: Parameter Store or CI Variable injection (AWS SSM)
# Here we take the Vault secret and put it in AWS SSM without exposing it in plaintext
resource "aws_ssm_parameter" "api_token_param" {
  name        = "/${var.app_name}/config/api_token"
  description = "API Token synced from Vault"
  type        = "SecureString"

  # Secret fetched from Vault and pushed to AWS SSM securely
  value = data.vault_generic_secret.api_token.data["token"]
}
