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

resource "proxmox_virtual_environment_vm" "node3_homeassistant_sandbox" {
  provider  = proxmox.node3
  name      = "homeassistant-sandbox"
  node_name = "node3"
  vm_id     = 111
  started   = true
  on_boot   = false
  tags      = ["sandbox", "hermes"]

  # Full clone of the production HA VM (node4/110). Cross-node clone:
  # source lives on node4, target lands on node3. USB/hostpci passthrough
  # on the source is hardware-local and is NOT carried over by clone —
  # verify with `qm config 111` after apply that no usb/hostpci lines exist.
  clone {
    vm_id     = 110
    node_name = "node4"
    full      = true
  }

  bios    = "ovmf"
  machine = "q35"

  agent {
    enabled = true
  }

  cpu {
    cores   = 4
    sockets = 1
    type    = "x86-64-v3"
  }

  memory {
    dedicated = 4096
  }

  efi_disk {
    datastore_id = "rpool"
    type         = "4m"
  }

  tpm_state {
    datastore_id = "rpool-zvols"
    version      = "v2.0"
  }

  # scsi0: rpool-zvols:vm-111-disk-0, 128G (matches prod source size)
  disk {
    interface    = "scsi0"
    datastore_id = "rpool-zvols"
    size         = 128
    iothread     = true
    discard      = "on"
  }

  # net0: node3 SDN bridge (isolated, NAT'd, no route to prod vmbr0 /
  # production HA / real Zigbee-Z-Wave USB sticks). Static lease 10.13.0.7.
  network_device {
    bridge      = "node3"
    mac_address = "D0:99:13:5A:11:CE"
    model       = "virtio"
  }

  serial_device {}

  # No usb {} blocks: sandbox must NOT get the real Zigbee/Z-Wave/BT
  # hardware passthrough. Confirmed absent post-clone (see docs).

  boot_order = ["scsi0", "ide2", "net0"]

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}
