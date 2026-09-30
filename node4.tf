module "node4" {
  source = "./modules/node4"

  providers = {
    proxmox = proxmox.node4
  }
}

output "talos_node4_cp_ips" {
  value = module.node4.talos_node4_cp_ips
}

output "talos_node4_worker_ips" {
  value = module.node4.talos_node4_worker_ips
}
