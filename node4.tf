# node4 — machine boundary module.
# All node4 infra (VMs, access, bridge) lives in modules/node4.
# Exclude from other-node applies with: -exclude=module.node4

module "node4" {
  source = "./modules/node4"

  providers = {
    proxmox = proxmox.node4
  }
}
