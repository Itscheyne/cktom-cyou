# Blind-secret consumption pattern for this repo's SOPS+age stack.
#
# The agent NEVER sees the plaintext. It only knows:
#   secret_file = "secrets/prod/rds-app-db.secrets.yaml"
#   secret_key  = "secret_value"
#
# CI holds the age private key (SOPS_AGE_KEY env var). The data source
# decrypts at plan/apply time inside the privileged CI environment.
# The resolved value is marked sensitive so it is redacted in all CLI output.
#
# WARNING: the resolved value WILL appear in .tfstate (T4 in the threat
# model). Harden your state backend (see docs/blind-secret-management.md §7).
# Prefer runtime injection (pass the file path to the workload; let it
# decrypt) when the resource supports it.

terraform {
  required_providers {
    # The carlpett/sops provider decrypts SOPS files natively inside OpenTofu.
    # Add to providers.tf:
    #   sops = {
    #     source  = "carlpett/sops"
    #     version = "~> 1.1"
    #   }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.1"
    }
  }
}

# Decrypt the agent-produced SOPS file and extract the target key.
data "sops_file" "secret" {
  source_file = var.secret_file
}

locals {
  # Mark sensitive immediately so it never appears in plan/apply output.
  secret_value = sensitive(data.sops_file.secret.data[var.secret_key])
}
