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

  # net1: node4 SDN internal zone (10.14.0.0/24) — live-only, added during drift reconciliation
  network_device {
    bridge      = "node4"
    mac_address = "D0:99:14:ED:92:21"
    model       = "virtio"
    firewall    = true
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
    dedicated = 6144 # live: 6144 (drift-reconciled)
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

resource "proxmox_virtual_environment_vm" "node4_vm_homeassistant" {
  provider  = proxmox
  name      = "VM-homeassistant"
  node_name = "node4"
  vm_id     = 103
  started   = false

  bios    = "ovmf"
  machine = "q35"

  agent {
    enabled = true
  }

  cpu {
    cores   = 4
    sockets = 1
    type    = "x86-64-v2-AES"
  }

  memory {
    dedicated = 6144
    floating  = 3072 # balloon
  }

  startup {
    order = 10
  }

  efi_disk {
    datastore_id = "imagepool0"
    type         = "4m"
  }

  # scsi1: imagepool0-zvols:vm-103-disk-5, 80G (secondary data disk)
  disk {
    interface    = "scsi1"
    datastore_id = "imagepool0-zvols"
    size         = 80
    iothread     = true
    discard      = "on"
  }

  # scsi2: imagepool0-zvols:vm-103-disk-1, 32G (boot disk)
  disk {
    interface    = "scsi2"
    datastore_id = "imagepool0-zvols"
    size         = 32
    iothread     = true
  }

  # unused0: imagepool0-zvols:subvol-103-disk-0
  # unused1: imagepool0-zvols:vm-103-disk-0
  # unused2: imagepool0-zvols:vm-103-disk-2
  # unused3: imagepool0-zvols:vm-103-disk-3
  # fleecing: imagepool0-zvols:vm-103-fleece-0, vm-103-fleece-1

  # net0: vmbr0, VLAN 2, firewall
  network_device {
    bridge      = "vmbr0"
    mac_address = "BC:24:11:E8:05:22"
    model       = "virtio"
    vlan_id     = 2
    firewall    = true
  }

  # net1: vmbr0, VLAN 3, firewall
  network_device {
    bridge      = "vmbr0"
    mac_address = "BC:24:11:E8:05:33"
    model       = "virtio"
    vlan_id     = 3
    firewall    = true
  }

  # USB passthrough
  usb {
    host = "10c4:ea60"
  }
  usb {
    host = "1a86:7523"
  }
  usb {
    host = "0a12:0001"
  }
  usb {
    host = "2357:0604"
  }

  boot_order = ["scsi2"]

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_vm" "node4_openneb" {
  provider  = proxmox
  name      = "openneb"
  node_name = "node4"
  vm_id     = 1040
  started   = false

  bios    = "ovmf"
  machine = "q35"

  agent {
    enabled = true
  }

  cpu {
    cores   = 4
    sockets = 1
    type    = "x86-64-v2-AES"
  }

  memory {
    dedicated = 4096
    floating  = 0 # balloon disabled
  }

  efi_disk {
    datastore_id      = "imagepool0"
    type              = "4m"
    pre_enrolled_keys = true
  }

  tpm_state {
    datastore_id = "imagepool0"
    version      = "v2.0"
  }

  # scsi0: imagepool0-zvols:vm-1040-disk-0, 80G (backup=0)
  disk {
    interface    = "scsi0"
    datastore_id = "imagepool0-zvols"
    size         = 80
    iothread     = true
    discard      = "on"
  }

  # ide2: datapool0:iso/ubuntu-25.10-desktop-amd64.iso
  cdrom {
    file_id = "datapool0:iso/ubuntu-25.10-desktop-amd64.iso"
  }

  # net0: vmbr0, VLAN 4, firewall
  network_device {
    bridge      = "vmbr0"
    mac_address = "D0:99:14:07:E4:15"
    model       = "virtio"
    vlan_id     = 4
    firewall    = true
  }

  boot_order = ["ide2", "scsi0", "net0"]

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_vm" "node4_incus" {
  provider  = proxmox
  name      = "incus"
  node_name = "node4"
  vm_id     = 2000
  started   = false

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
    dedicated = 8192
  }

  efi_disk {
    datastore_id = "imagepool0"
    type         = "4m"
  }

  tpm_state {
    datastore_id = "imagepool0"
    version      = "v2.0"
  }

  # scsi0: imagepool0-zvols:vm-2000-disk-0, 64G
  disk {
    interface    = "scsi0"
    datastore_id = "imagepool0-zvols"
    size         = 64
    iothread     = true
    discard      = "on"
  }

  # scsi1: imagepool0-zvols:vm-2000-disk-1, 90G
  disk {
    interface    = "scsi1"
    datastore_id = "imagepool0-zvols"
    size         = 90
    iothread     = true
  }

  # net0: vmbr0, VLAN 4
  network_device {
    bridge      = "vmbr0"
    mac_address = "D0:99:14:36:2E:FF"
    model       = "virtio"
    vlan_id     = 4
  }

  # boot: (empty — boot disabled)

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_vm" "node4_cp0" {
  provider  = proxmox
  name      = "cp0"
  node_name = "node4"
  vm_id     = 900
  started   = false

  # SeaBIOS (no bios/machine field)

  agent {
    enabled = true
  }

  cpu {
    cores   = 4
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = 4096
    floating  = 0 # balloon disabled
  }

  # scsi0: imagepool0-zvols:vm-900-disk-0, 64G (linked clone from base-800)
  disk {
    interface    = "scsi0"
    datastore_id = "imagepool0-zvols"
    size         = 64
    iothread     = true
  }

  # scsi1: imagepool0-zvols:vm-900-disk-1, 128G
  disk {
    interface    = "scsi1"
    datastore_id = "imagepool0-zvols"
    size         = 128
    iothread     = true
  }

  # net0: vmbr0, VLAN 4, firewall
  network_device {
    bridge      = "vmbr0"
    mac_address = "D0:99:14:5E:87:39"
    model       = "virtio"
    vlan_id     = 4
    firewall    = true
  }

  boot_order = ["scsi0"]

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_vm" "node4_w1" {
  provider  = proxmox
  name      = "w1"
  node_name = "node4"
  vm_id     = 901
  started   = false

  # SeaBIOS (no bios/machine field)

  agent {
    enabled = true
  }

  cpu {
    cores   = 3
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = 4096
    floating  = 0 # balloon disabled
  }

  # scsi0: imagepool0-zvols:vm-901-disk-0, 32G (linked clone from base-800)
  disk {
    interface    = "scsi0"
    datastore_id = "imagepool0-zvols"
    size         = 32
    iothread     = true
  }

  # scsi1: imagepool0-zvols:vm-901-disk-1, 128G
  disk {
    interface    = "scsi1"
    datastore_id = "imagepool0-zvols"
    size         = 128
    iothread     = true
  }

  # net0: vmbr0, VLAN 4, firewall
  network_device {
    bridge      = "vmbr0"
    mac_address = "D0:99:14:B0:E3:72"
    model       = "virtio"
    vlan_id     = 4
    firewall    = true
  }

  boot_order = ["scsi0", "ide2"]

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_vm" "node4_dev" {
  provider  = proxmox
  name      = "dev"
  node_name = "node4"
  vm_id     = 999
  started   = false

  bios    = "ovmf"
  machine = "q35"

  agent {
    enabled = true
  }

  cpu {
    cores   = 5
    sockets = 1
    type    = "x86-64-v3"
  }

  memory {
    dedicated = 8192
  }

  efi_disk {
    datastore_id = "imagepool0"
    type         = "4m"
  }

  tpm_state {
    datastore_id = "imagepool0"
    version      = "v2.0"
  }

  # No active disk! unused0: imagepool0-zvols:vm-999-disk-0 (detached)

  # net0: vmbr0, VLAN 3
  network_device {
    bridge      = "vmbr0"
    mac_address = "D0:99:14:CF:85:FF"
    model       = "virtio"
    vlan_id     = 3
  }

  boot_order = ["ide2", "net0"]

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

# ── Templates ────────────────────────────────

resource "proxmox_virtual_environment_vm" "node4_almacloud_template" {
  provider  = proxmox
  name      = "almacloud-template"
  node_name = "node4"
  vm_id     = 202
  started   = false
  template  = true
  on_boot   = true

  bios    = "ovmf"
  machine = "q35"

  agent {
    enabled = true
  }

  cpu {
    cores   = 3
    sockets = 1
    type    = "x86-64-v2-AES"
  }

  memory {
    dedicated = 4096
    floating  = 2048 # balloon
  }

  efi_disk {
    datastore_id      = "imagepool0"
    type              = "4m"
    pre_enrolled_keys = true
  }

  # scsi0: imagepool0-zvols:vm-202-disk-0, 20G
  disk {
    interface    = "scsi0"
    datastore_id = "imagepool0-zvols"
    size         = 20
    iothread     = true
  }

  # scsi1: imagepool0-zvols:vm-202-disk-1, 20G
  disk {
    interface    = "scsi1"
    datastore_id = "imagepool0-zvols"
    size         = 20
    iothread     = true
  }

  # Cloud-init: root user, vendor config from datapool0:snippets/201-cloudinit-vendor.yaml
  initialization {
    user_account {
      username = "root"
    }
    ip_config {
      ipv4 {
        address = "dhcp"
      }
      ipv6 {
        address = "dhcp"
      }
    }
  }

  # unused0: datapool0:202/vm-202-disk-0.raw

  # net0: vmbr0, VLAN 4, firewall
  network_device {
    bridge      = "vmbr0"
    mac_address = "BC:24:11:C5:FF:F6"
    model       = "virtio"
    vlan_id     = 4
    firewall    = true
  }

  boot_order = ["ide2", "net0"]

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_vm" "node4_flustercuck_template" {
  provider  = proxmox
  name      = "flustercuck-template"
  node_name = "node4"
  vm_id     = 800
  started   = false
  template  = true
  on_boot   = true
  tags      = ["controlplane", "talos"]

  bios    = "ovmf"
  machine = "q35"

  agent {
    enabled = true
  }

  cpu {
    cores   = 3
    sockets = 1
    type    = "x86-64-v2-AES"
  }

  memory {
    dedicated = 4096
    floating  = 0 # balloon disabled
  }

  efi_disk {
    datastore_id      = "imagepool0"
    type              = "4m"
    pre_enrolled_keys = true
  }

  # scsi0: imagepool0-zvols:base-800-disk-0, 64G (linked clone source)
  disk {
    interface    = "scsi0"
    datastore_id = "imagepool0-zvols"
    size         = 64
    iothread     = true
  }

  # ide2: datapool0:iso/nocloud-amd64.iso
  cdrom {
    file_id = "datapool0:iso/nocloud-amd64.iso"
  }

  # net0: vmbr0, VLAN 4
  network_device {
    bridge      = "vmbr0"
    mac_address = "D0:99:14:52:89:8A"
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

resource "proxmox_virtual_environment_vm" "node4_talos_template" {
  provider  = proxmox
  name      = "talos-template"
  node_name = "node4"
  vm_id     = 899
  started   = false
  template  = true
  on_boot   = true

  # SeaBIOS (no bios/machine field)

  agent {
    enabled = true
  }

  cpu {
    cores   = 4
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = 4096
    floating  = 0 # balloon disabled
  }

  # scsi0: datapool0-zvols:base-899-disk-0, 32G (linked clone source)
  disk {
    interface    = "scsi0"
    datastore_id = "datapool0-zvols"
    size         = 32
    iothread     = true
  }

  # ide2: datapool0:iso/nocloud-amd64.iso
  cdrom {
    file_id = "datapool0:iso/nocloud-amd64.iso"
  }

  # net0: vmbr0, VLAN 4, firewall
  network_device {
    bridge      = "vmbr0"
    mac_address = "D0:99:14:A9:19:EE"
    model       = "virtio"
    vlan_id     = 4
    firewall    = true
  }

  boot_order = ["scsi0", "ide2", "net0"]

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

# node4_fipa (vm_id 150) removed: VM no longer exists live on node4 (drift-reconciled,
# see DRIFT.md). State entry removed via `tofu state rm`.
