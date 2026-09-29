# node4 — machine boundary module.
# All node4 infra (VMs, access, bridge) lives in modules/node4.
# Exclude from other-node applies with: -exclude=module.node4

module "node4" {
  source = "./modules/node4"

  providers = {
    proxmox = proxmox.node4
  }
}

output "talos_node4_ips" {
  description = "Allocated IPv4 addresses for Talos node on node4"
  value       = module.node4.talos_node4_ips
}

