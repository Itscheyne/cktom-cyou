# node1 — machine boundary module.
# All node1 infra (VMs, CTs, access, Talos cluster) lives in modules/node1.
# Exclude from node3/node4-only applies with: -exclude=module.node1
# (node1 is frequently offline; excluding it keeps plan/apply from hanging.)

module "node1" {
  source = "./modules/node1"

  providers = {
    proxmox = proxmox.node1
  }

  talos_version                = var.talos_version
  talos_cluster_name           = var.talos_cluster_name
  talos_netbird_setup_key      = var.talos_netbird_setup_key
  talos_netbird_management_url = var.talos_netbird_management_url
}

# Re-export Talos outputs (preserve `tofu output kubeconfig` UX).
output "kubeconfig" {
  value     = module.node1.kubeconfig
  sensitive = true
}

output "talosconfig" {
  value     = module.node1.talosconfig
  sensitive = true
}
