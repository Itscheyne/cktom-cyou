# ──────────────────────────────────────────────
# node3 - Proxmox Host
# 16 CPU cores, ~62 GB RAM, ~1.5 TB root disk
#
# ZFS pools: rpool, datapool0, datapool1
# Storage backends: rpool-zvols, datapool0-zvols, datapool1-zvols,
#                   rpool (dir), datapool0 (dir), datapool1 (dir), local (dir)
# ──────────────────────────────────────────────

# ── Running VMs ──────────────────────────────

resource "proxmox_virtual_environment_vm" "node3_nast" {
  provider  = proxmox.node3
  name      = "nast"
  node_name = "node3"
  vm_id     = 400
  started   = false

  bios    = "ovmf"
  machine = "q35"

  agent {
    enabled = true
  }

  cpu {
    cores   = 4
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = 7164
  }

  efi_disk {
    datastore_id = "datapool0"
    type         = "4m"
  }

  # scsi1: rpool-zvols:vm-400-disk-0, 96G
  disk {
    interface    = "scsi1"
    datastore_id = "rpool-zvols"
    size         = 96
    iothread     = true
  }

  # scsi2: datapool0-zvols:vm-400-disk-1, 2T
  disk {
    interface    = "scsi2"
    datastore_id = "datapool0-zvols"
    size         = 2048
    iothread     = true
    discard      = "on"
  }

  # net0: vmbr2, VLAN 3 (management)
  network_device {
    bridge      = "vmbr2"
    mac_address = "D0:99:13:62:C6:B6"
    model       = "virtio"
    vlan_id     = 3
  }

  # net1: node3 SDN bridge (10.13.0.5 via DHCP)
  network_device {
    bridge      = "node3"
    mac_address = "D0:99:13:49:50:5A"
    model       = "virtio"
  }

  boot_order = ["net0"]

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_vm" "node3_utm" {
  provider  = proxmox.node3
  name      = "utm"
  node_name = "node3"
  vm_id     = 490
  started   = true

  bios    = "ovmf"
  machine = "q35"

  agent {
    enabled = true
  }

  cpu {
    cores   = 6
    sockets = 1
    type    = "x86-64-v3"
  }

  memory {
    dedicated = 16834
  }

  efi_disk {
    datastore_id      = "rpool"
    type              = "4m"
    pre_enrolled_keys = true
  }

  tpm_state {
    datastore_id = "rpool"
    version      = "v2.0"
  }

  # scsi0: rpool-zvols:vm-490-disk-0, ~240.5G (246272M)
  disk {
    interface    = "scsi0"
    datastore_id = "rpool-zvols"
    size         = 241 # 246272M
    discard      = "on"
  }

  # scsi1: datapool0-zvols:vm-490-disk-0, 768G
  disk {
    interface    = "scsi1"
    datastore_id = "datapool0-zvols"
    size         = 768
    discard      = "on"
  }

  # virtio0: datapool1-zvols:vm-490-disk-0, 256G
  disk {
    interface    = "virtio0"
    datastore_id = "datapool1-zvols"
    size         = 256
    iothread     = true
    discard      = "on"
  }

  # Cloud-init: custom network + user from datapool0:snippets/
  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
      ipv6 {
        address = "dhcp"
      }
    }
  }

  # net0: vmbr0, VLAN 4
  network_device {
    bridge      = "vmbr0"
    mac_address = "D0:99:13:F6:0E:5A"
    model       = "virtio"
    vlan_id     = 4
  }

  serial_device {}

  vga {
    type = "std"
  }

  boot_order = ["scsi0"]

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_vm" "node3_so" {
  provider  = proxmox.node3
  name      = "so"
  node_name = "node3"
  vm_id     = 500
  started   = true

  bios    = "ovmf"
  machine = "q35"

  agent {
    enabled = true
  }

  cpu {
    cores   = 12
    sockets = 1
    type    = "x86-64-v3"
  }

  memory {
    dedicated = 28672
  }

  efi_disk {
    datastore_id = "rpool-zvols"
    type         = "4m"
  }

  # scsi0: rpool-zvols:vm-500-disk-2, 100G
  disk {
    interface    = "scsi0"
    datastore_id = "rpool-zvols"
    size         = 100
    iothread     = true
    discard      = "on"
  }

  # scsi1: rpool-zvols:vm-500-disk-3, 612G
  disk {
    interface    = "scsi1"
    datastore_id = "rpool-zvols"
    size         = 612
    iothread     = true
  }

  # unused0: datapool0-zvols:vm-500-disk-0
  # unused1: datapool0-zvols:vm-500-disk-0-then
  # unused2: rpool-zvols:vm-500-disk-0

  # net0: vmbr0, VLAN 4
  network_device {
    bridge      = "vmbr0"
    mac_address = "BC:24:13:07:94:00"
    model       = "virtio"
    vlan_id     = 4
  }

  # net1: vmbr1 (sniffing bridge, 10G SFP+), mtu=1
  network_device {
    bridge      = "vmbr1"
    mac_address = "BC:24:13:E8:80:11"
    model       = "virtio"
    mtu         = 1
  }

  serial_device {}

  boot_order = ["scsi0", "ide2"]

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_vm" "node3_so_oc" {
  provider  = proxmox.node3
  name      = "so-oc"
  node_name = "node3"
  vm_id     = 501
  started   = false # currently stopped but onboot=1

  agent {
    enabled = true
  }

  cpu {
    cores   = 3
    sockets = 1
    type    = "x86-64-v3"
    units   = 80
  }

  memory {
    dedicated = 3072
    floating  = 2048 # balloon
  }

  # scsi0: rpool-zvols:vm-501-disk-0, 64G
  disk {
    interface    = "scsi0"
    datastore_id = "rpool-zvols"
    size         = 64
    iothread     = true
  }

  # ide2: datapool1:iso/securityonion-2.4.141-20250331.iso
  cdrom {
    file_id = "datapool1:iso/securityonion-2.4.141-20250331.iso"
  }

  # net0: vmbr2, VLAN 4
  network_device {
    bridge      = "vmbr2"
    mac_address = "D0:99:13:6A:A1:DA"
    model       = "virtio"
    vlan_id     = 4
  }

  # net1: vmbr0, VLAN 3, firewall
  network_device {
    bridge      = "vmbr0"
    mac_address = "D0:99:13:37:19:0A"
    model       = "virtio"
    vlan_id     = 3
    firewall    = true
  }

  boot_order = ["net0"]

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_vm" "node3_prod3" {
  provider  = proxmox.node3
  name      = "prod3"
  node_name = "node3"
  vm_id     = 800
  started   = true

  # SeaBIOS (no bios field = default)

  cpu {
    cores   = 8
    sockets = 1
    type    = "x86-64-v3"
  }

  memory {
    dedicated = 10240
  }

  # Cloud-init configuration
  initialization {
    user_account {
      username = "prodmin"
    }
    dns {
      servers = ["10.0.3.1"]
      domain  = "sf.cktom.cyou"
    }
    ip_config {
      ipv4 {
        address = "dhcp"
      }
      ipv6 {
        address = "dhcp"
      }
    }
    ip_config {
      ipv4 {
        address = "dhcp"
      }
      ipv6 {
        address = "dhcp"
      }
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

  # scsi1: rpool-zvols:vm-800-disk-0, 128G (note: scsi1, not scsi0)
  disk {
    interface    = "scsi1"
    datastore_id = "rpool-zvols"
    size         = 128
  }

  # unused0: datapool0-zvols:vm-800-disk-0
  # virtiofs0: stash-data (datapool0/data/filesystems/stash-data, 2.6T)
  # virtiofs1: prod3 (datapool0/data/filesystems/prod3, 71.7G)
  # Note: virtiofs mounts are not manageable via the provider

  # net0: node3 SDN bridge (10.13.0.2 via DHCP), link_down=1
  network_device {
    bridge      = "node3"
    mac_address = "D0:99:13:08:00:01"
    model       = "virtio"
  }

  # net1: vmbr2, VLAN 3, mtu=1
  network_device {
    bridge      = "vmbr2"
    mac_address = "D0:99:13:08:00:03"
    model       = "virtio"
    vlan_id     = 3
    mtu         = 1
  }

  # net2: vmbr2, VLAN 4, mtu=1
  network_device {
    bridge      = "vmbr2"
    mac_address = "D0:99:13:08:00:04"
    model       = "virtio"
    vlan_id     = 4
    mtu         = 1
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

# ── Stopped VMs ──────────────────────────────

resource "proxmox_virtual_environment_vm" "node3_homeassistant_test" {
  provider  = proxmox.node3
  name      = "homeassistant-test"
  node_name = "node3"
  vm_id     = 10110
  started   = true
  tags      = ["dev"]

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
    dedicated = 2048
  }

  efi_disk {
    datastore_id = "rpool"
    type         = "4m"
  }

  # scsi0: rpool-zvols:vm-10110-disk-0, 32G
  disk {
    interface    = "scsi0"
    datastore_id = "rpool-zvols"
    size         = 32
    iothread     = true
  }

  # net0: node3 SDN bridge (10.13.0.6 via DHCP)
  network_device {
    bridge      = "node3"
    mac_address = "D0:99:13:52:E5:BA"
    model       = "virtio"
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_vm" "node3_homeassistant" {
  provider  = proxmox.node3
  name      = "homeassistant"
  node_name = "node3"
  vm_id     = 110
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

  # scsi0: rpool-zvols:vm-110-disk-0, 128G
  disk {
    interface    = "scsi0"
    datastore_id = "rpool-zvols"
    size         = 128
    iothread     = true
    discard      = "on"
  }

  # net0: vmbr2 (2.5GbE bridge)
  network_device {
    bridge      = "vmbr2"
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

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

# ── Templates ────────────────────────────────

resource "proxmox_virtual_environment_vm" "node3_alma_template" {
  provider  = proxmox.node3
  name      = "alma-template"
  node_name = "node3"
  vm_id     = 700
  started   = false
  template  = true

  bios    = "ovmf"
  machine = "q35"

  cpu {
    cores   = 4
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = 4096
  }

  efi_disk {
    datastore_id = "imagepool0"
    type         = "4m"
  }

  # scsi0: imagepool0:700/base-700-disk-0.raw, 10G
  disk {
    interface    = "scsi0"
    datastore_id = "imagepool0"
    size         = 10
  }

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

  # net0: vmbr2, VLAN 4
  network_device {
    bridge      = "vmbr2"
    mac_address = "BC:24:13:A4:CE:97"
    model       = "virtio"
    vlan_id     = 4
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

# ── LXC Containers ──────────────────────────

resource "proxmox_virtual_environment_container" "node3_storage" {
  provider    = proxmox.node3
  description = "Storage LXC container"
  node_name   = "node3"
  vm_id       = 777
  started     = false

  cpu {
    cores = 4
  }

  memory {
    dedicated = 1024
  }

  disk {
    datastore_id = "local"
    size         = 20
  }

  operating_system {
    template_file_id = "local:vztmpl/placeholder.tar.xz"
    type             = "unmanaged"
  }

  lifecycle {
    ignore_changes = all
  }
}

# ── Additional VMs (previously unmanaged) ─────

resource "proxmox_virtual_environment_vm" "node3_dev" {
  provider  = proxmox.node3
  name      = "dev"
  node_name = "node3"
  vm_id     = 299
  started   = true

  cpu {
    cores   = 6
    sockets = 1
    type    = "x86-64-v3"
  }

  memory {
    dedicated = 12000
  }

  efi_disk {
    datastore_id = "rpool"
    type         = "4m"
  }

  disk {
    interface    = "virtio0"
    datastore_id = "rpool-zvols"
    size         = 128
    iothread     = true
    file_format  = "raw"
  }

  network_device {
    bridge      = "vmbr2"
    mac_address = "D0:99:13:F6:AF:9A"
    model       = "virtio"
    firewall    = true
    vlan_id     = 4
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_vm" "node3_fipa" {
  provider  = proxmox.node3
  name      = "fipa"
  node_name = "node3"
  vm_id     = 389
  started   = false

  cpu {
    cores   = 4
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = 3072
  }

  efi_disk {
    datastore_id = "rpool"
    type         = "4m"
  }

  network_device {
    bridge      = "vmbr2"
    mac_address = "D0:99:13:89:05:8A"
    model       = "virtio"
    firewall    = true
    vlan_id     = 3
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_vm" "node3_prod3_1" {
  provider  = proxmox.node3
  name      = "prod3-1"
  node_name = "node3"
  vm_id     = 801
  started   = false

  bios    = "ovmf"
  machine = "q35"

  cpu {
    cores   = 8
    sockets = 1
    type    = "x86-64-v3"
  }

  memory {
    dedicated = 10240
  }

  efi_disk {
    datastore_id = "rpool"
    type         = "4m"
  }

  disk {
    interface    = "scsi1"
    datastore_id = "rpool-zvols"
    size         = 128
    file_format  = "raw"
  }

  # net0: node3 SDN bridge
  network_device {
    bridge      = "node3"
    mac_address = "D0:99:13:C9:98:FF"
    model       = "virtio"
  }

  # net1: vmbr2 VLAN 3
  network_device {
    bridge      = "vmbr2"
    mac_address = "D0:99:13:36:CE:1B"
    model       = "virtio"
    mtu         = 1
    vlan_id     = 3
  }

  # net2: vmbr2 VLAN 4
  network_device {
    bridge      = "vmbr2"
    mac_address = "D0:99:13:DD:79:E7"
    model       = "virtio"
    mtu         = 1
    vlan_id     = 4
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_vm" "node3_dev3" {
  provider  = proxmox.node3
  name      = "dev3"
  node_name = "node3"
  vm_id     = 901
  started   = false

  cpu {
    cores   = 6
    sockets = 1
    type    = "x86-64-v2-AES"
  }

  memory {
    dedicated = 6144
  }

  efi_disk {
    datastore_id = "rpool"
    type         = "4m"
  }

  disk {
    interface    = "virtio0"
    datastore_id = "rpool-zvols"
    size         = 128
    iothread     = true
    file_format  = "raw"
  }

  network_device {
    bridge      = "vmbr2"
    mac_address = "D0:99:13:D1:97:7B"
    model       = "virtio"
    firewall    = true
    vlan_id     = 3
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_vm" "node3_prod3_0" {
  provider  = proxmox.node3
  name      = "prod3-0"
  node_name = "node3"
  vm_id     = 8001
  started   = false

  cpu {
    cores   = 6
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = 8192
  }

  efi_disk {
    datastore_id = "rpool"
    type         = "4m"
  }

  network_device {
    bridge      = "node3"
    mac_address = "D0:99:13:99:51:FC"
    model       = "virtio"
    firewall    = true
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_container" "node3_nast" {
  provider  = proxmox.node3
  node_name = "node3"
  vm_id     = 445
  started   = true
  tags      = ["infra"]

  cpu {
    cores = 5
  }

  memory {
    dedicated = 6144
  }

  disk {
    datastore_id = "rpool-zvols"
    size         = 20
  }

  network_interface {
    name        = "sf"
    bridge      = "vmbr2"
    firewall    = true
    mac_address = "D0:99:13:EB:54:10"
    vlan_id     = 3
  }

  operating_system {
    template_file_id = "local:vztmpl/placeholder.tar.xz"
    type             = "debian"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_container" "node3_dir" {
  provider  = proxmox.node3
  node_name = "node3"
  vm_id     = 10389
  started   = true

  cpu {
    cores = 2
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = "rpool-zvols"
    size         = 32
  }

  network_interface {
    name        = "node3"
    bridge      = "node3"
    firewall    = true
    mac_address = "D0:99:13:4C:1F:C2"
  }

  operating_system {
    template_file_id = "local:vztmpl/placeholder.tar.xz"
    type             = "fedora"
  }

  lifecycle {
    ignore_changes = all
  }
}
