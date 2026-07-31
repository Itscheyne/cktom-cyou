# node3 network bridges — moved from root networking.tf.
#
# Physical NICs:
#   enp11s0 — RTL8111H 1GbE          → vmbr0 (main bridge)
#   enp8s0  — Intel 82599ES 10G SFP+ → vmbr1 (sniffing/mirror, MTU 9000)
#   enp7s0  — I225-V 2.5GbE          → vmbr2 (VLAN-aware, VIDs 2-4)

resource "proxmox_network_linux_bridge" "node3_vmbr0" {
  provider  = proxmox
  node_name = "node3"
  name      = "vmbr0"

  ports      = ["enp11s0"]
  vlan_aware = true
  autostart  = true

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_network_linux_bridge" "node3_vmbr1" {
  provider  = proxmox
  node_name = "node3"
  name      = "vmbr1"

  ports      = ["enp8s0"]
  vlan_aware = false
  mtu        = 9000
  autostart  = true

  # Sniffing/mirror bridge — STP off, aging 0, offloads disabled via post-up

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_network_linux_bridge" "node3_vmbr2" {
  provider  = proxmox
  node_name = "node3"
  name      = "vmbr2"

  ports      = ["enp7s0"]
  vlan_aware = true
  autostart  = true

  lifecycle {
    ignore_changes = all
  }
}
