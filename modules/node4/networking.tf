# node4 network bridge — moved from root networking.tf.
#
# Physical NICs:
#   eno1 — onboard NIC → vmbr0 (main bridge)

resource "proxmox_network_linux_bridge" "node4_vmbr0" {
  provider  = proxmox
  node_name = "node4"
  name      = "vmbr0"

  ports      = ["eno1"]
  vlan_aware = true
  autostart  = true

  lifecycle {
    ignore_changes = all
  }
}
