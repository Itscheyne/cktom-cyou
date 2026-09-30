module "node3" {
  source = "./modules/node3"

  providers = {
    proxmox = proxmox.node3
  }
}

output "talos_node3_cp_ips" {
  value = module.node3.talos_node3_cp_ips
}

output "talos_node3_worker_ips" {
  value = module.node3.talos_node3_worker_ips
}
