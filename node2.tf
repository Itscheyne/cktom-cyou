# node2 — machine boundary module.
# All node2 infra (VMs, access, bridge) lives in modules/node2.
# Exclude from other-node applies with: -exclude=module.node2

module "node2" {
  source = "./modules/node2"

  providers = {
    proxmox = proxmox.node2
  }
}

