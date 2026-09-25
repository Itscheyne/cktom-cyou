# node3 — machine boundary module.
# All node3 infra (VMs, CTs, access, bridges, pools) lives in modules/node3.
# Exclude from other-node applies with: -exclude=module.node3

module "node3" {
  source = "./modules/node3"

  providers = {
    proxmox = proxmox.node3

  }
}

# ── Hermes HA Sandbox ────────────────────────
#
# Full clone of the production Home Assistant VM (node4/homeassistant-HA,
# vm_id 110), used as an isolated experimentation sandbox for Hermes.
# Network-isolated on the node3 SDN bridge (NAT'd, no route to prod vmbr0,
# no access to production HA instance or the real Zigbee/Z-Wave USB stick).
# See docs/ha-sandbox.md for the clone/reset procedure.


output "talos_node3_ips" {
  description = "Allocated IPv4 addresses for Talos node on node3"
  value       = module.node3.talos_node3_ips
}
