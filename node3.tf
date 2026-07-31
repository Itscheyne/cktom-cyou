# node3 — machine boundary module.
# All node3 infra (VMs, CTs, access, bridges, pools) lives in modules/node3.
# Exclude from other-node applies with: -exclude=module.node3

module "node3" {
  source = "./modules/node3"

  providers = {
    proxmox = proxmox.node3
  }
}
