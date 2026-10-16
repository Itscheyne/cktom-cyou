output "secret_value" {
  description = "The resolved plaintext secret. Sensitive — never printed. Pass directly to resource attributes."
  value       = local.secret_value
  sensitive   = true
}

output "secret_file" {
  description = "The SOPS file path (the blind reference). Safe to log."
  value       = var.secret_file
}
