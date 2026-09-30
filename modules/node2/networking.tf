# node2 network bridge

resource "proxmox_network_linux_bridge" "node2_vmbr0" {
  provider  = proxmox
  node_name = "node2"
  name      = "vmbr0"

  ports      = ["eno2"]
  vlan_aware = true
  autostart  = true

  lifecycle {
    ignore_changes = all
  }
}
