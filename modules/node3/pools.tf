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

resource "proxmox_virtual_environment_pool" "dev" {
  provider = proxmox
  pool_id  = "dev"
  comment  = "for dev stuff"
}

resource "proxmox_virtual_environment_pool" "prod" {
  provider = proxmox
  pool_id  = "prod"
  comment  = "for prod stuff"
}
