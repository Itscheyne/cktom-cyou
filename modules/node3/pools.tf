# node3 resource pools — moved from root pools.tf.

resource "proxmox_virtual_environment_pool" "security_onion" {
  provider = proxmox
  pool_id  = "SecurityOnion"
}

resource "proxmox_virtual_environment_pool" "mosse" {
  provider = proxmox
  pool_id  = "mosse"
}

resource "proxmox_virtual_environment_pool" "talos" {
  provider = proxmox
  pool_id  = "talos"
}
