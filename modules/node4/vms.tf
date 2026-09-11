# ──────────────────────────────────────────────
# node4 - Proxmox Host
# 8 CPU cores, ~14.6 GB RAM, ~44 GB root disk
#
# ZFS pools: rpool, datapool0, imagepool0
# Storage backends: imagepool0-zvols, datapool0-zvols,
#                   imagepool0 (dir), datapool0 (dir), rpool (dir), local (dir)
# ──────────────────────────────────────────────

# ── Running VMs ──────────────────────────────

resource "proxmox_virtual_environment_vm" "node4_pdm" {
  provider  = proxmox
  name      = "pdm"
  node_name = "node4"
  vm_id     = 1001
  started   = true
  on_boot   = true

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
    dedicated = 5020
  }

  efi_disk {
    datastore_id = "imagepool0"
    type         = "4m"
  }

  tpm_state {
    datastore_id = "imagepool0"
    version      = "v2.0"
  }

  # scsi0: imagepool0-zvols:vm-1001-disk-0, 64G
  disk {
    interface    = "scsi0"
    datastore_id = "imagepool0-zvols"
    size         = 64
    iothread     = true
    discard      = "on"
  }

  # ide2: datapool0:iso/proxmox-datacenter-manager_1.0-2.iso
  cdrom {
    file_id = "datapool0:iso/proxmox-datacenter-manager_1.0-2.iso"
  }

  # net0: vmbr0, VLAN 4
  network_device {
    bridge      = "vmbr0"
    mac_address = "D0:99:14:50:1D:99"
    model       = "virtio"
    vlan_id     = 4
  }

  boot_order = ["scsi0", "ide2", "net0"]

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_vm" "node4_homeassistant_ha" {
  provider  = proxmox
  name      = "homeassistant-HA"
  node_name = "node4"
  vm_id     = 110
  started   = true
  on_boot   = true

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
    datastore_id = "imagepool0"
    type         = "4m"
  }

  tpm_state {
    datastore_id = "imagepool0-zvols"
    version      = "v2.0"
  }

  # scsi0: imagepool0-zvols:vm-110-disk-0, 128G
  disk {
    interface    = "scsi0"
    datastore_id = "imagepool0-zvols"
    size         = 128
    iothread     = true
    discard      = "on"
  }

  # net0: vmbr0 (untagged)
  network_device {
    bridge      = "vmbr0"
    mac_address = "BC:24:11:E8:05:22"
    model       = "virtio"
  }

  serial_device {}

  # USB passthrough: Bluetooth, serial adapters
  usb {
    host = "0a12:0001"
  }
  usb {
    host = "1a86:7523"
  }
  usb {
    host = "10c4:ea60"
  }
  usb {
    host = "8087:0a2a"
  }

  boot_order = ["ide2", "net0"]

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

# ── Stopped VMs ──────────────────────────────







# ── Templates ────────────────────────────────




