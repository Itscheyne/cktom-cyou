# 5. Example: Proxmox VMs and Cloud-Init
# How to map an agent-provided blind reference (like a Vault or SOPS secret) 
# to a Proxmox VM without revealing the plaintext.

# variable "vm_ssh_private_key_path" { description = "Vault path for VM SSH key" }

# data "vault_generic_secret" "ssh_key" {
#   path = var.vm_ssh_private_key_path
# }

# resource "proxmox_virtual_environment_file" "cloud_init_secret" {
#   content_type = "snippets"
#   datastore_id = "local"
#   node_name    = "node3"
#
#   # Pass secret data into a cloud-config snippet.
#   # Use HEREDOC or templatefile.
#   source_raw {
#     data = <<-EOF
#     #cloud-config
#     write_files:
#       - path: /etc/secret-key
#         permissions: '0600'
#         content: |
#           ${indent(10, data.vault_generic_secret.ssh_key.data["private_key"])}
#     EOF
#     file_name = "secret-snippet.yaml"
#   }
# }

# resource "proxmox_virtual_environment_vm" "example_vm" {
#   name      = "example-vm-secrets"
#   node_name = "node3"
#
#   initialization {
#     user_data_file_id = proxmox_virtual_environment_file.cloud_init_secret.id
#   }
# }
