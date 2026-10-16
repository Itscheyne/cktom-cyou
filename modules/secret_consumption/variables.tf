variable "secret_file" {
  description = "Relative path to the SOPS-encrypted secrets YAML file (e.g. secrets/prod/rds-app-db.secrets.yaml). This is the blind reference returned by secret_create.py."
  type        = string
}

variable "secret_key" {
  description = "Key within the SOPS-encrypted YAML to extract (e.g. secret_value)."
  type        = string
  default     = "secret_value"
}
