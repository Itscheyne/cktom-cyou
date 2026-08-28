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
  provider  = proxmox
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
    dedicated = 4096
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

  # virtio0: datapool0-zvols:vm-400-disk-0, 4T
  disk {
    interface    = "virtio0"
    datastore_id = "datapool0-zvols"
    size         = 4096
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

  # net1: node3 SDN bridge, 10.13.0.5 (DHCP)
  network_device {
    bridge      = "node3"
    mac_address = "D0:99:13:49:50:5A"
    model       = "virtio"
  }

  boot_order = ["scsi1"]

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_vm" "node3_utm" {
  provider  = proxmox
  name      = "utm"
  node_name = "node3"
  vm_id     = 490
  started   = false # live: stopped (drift-reconciled)

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
  provider  = proxmox
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

  # scsi0: rpool-zvols:vm-500-disk-3, 812G
  disk {
    interface    = "scsi0"
    datastore_id = "rpool-zvols"
    size         = 812
    iothread     = true
  }

  # scsi1: rpool-zvols:vm-500-disk-2, 100G
  disk {
    interface    = "scsi1"
    datastore_id = "rpool-zvols"
    size         = 100
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

  boot_order = ["ide2"]

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_vm" "node3_so_oc" {
  provider  = proxmox
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
  provider  = proxmox
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
  provider  = proxmox
  name      = "homeassistant-test"
  node_name = "node3"
  vm_id     = 10110
  started   = false # live: stopped (drift-reconciled)
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
  provider  = proxmox
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
  provider  = proxmox
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
  provider    = proxmox
  description = "Storage LXC container"
  node_name   = "node3"
  vm_id       = 777
  started     = false
  # live: hostname=storage (drift-reconciled)
  initialization {
    hostname = "storage"
  }

  cpu {
    cores = 4
  }

  memory {
    dedicated = 1024
  }

  disk { # live: rootfs imagepool0-zvols:subvol-777-disk-0, 20G (drift-reconciled: was local)
    datastore_id = "imagepool0-zvols"
    size         = 20
  }

  network_interface { # live net0: bridge=vmbr0 (live-only, undeclared until now)
    name        = "eth0"
    bridge      = "vmbr0"
    mac_address = "D0:99:13:EA:94:9B"
  }

  network_interface { # live net1: bridge=vmbr2, VLAN 3 (live-only, undeclared until now)
    name        = "eth1"
    bridge      = "vmbr2"
    mac_address = "D0:99:13:C0:E7:F2"
    vlan_id     = 3
  }

  operating_system {
    template_file_id = "local:vztmpl/placeholder.tar.xz"
    type             = "debian" # live: debian (drift-reconciled: was unmanaged)
  }

  lifecycle {
    ignore_changes = all
  }
}

# ── Additional VMs (previously unmanaged) ─────

resource "proxmox_virtual_environment_vm" "node3_dev" {
  provider  = proxmox
  name      = "dev"
  node_name = "node3"
  vm_id     = 299
  started   = true

  cpu {
    cores   = 6
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = 6144 # live: 6144 (drift-reconciled)
  }

  efi_disk {
    datastore_id = "rpool"
    type         = "4m"
  }

  # virtio0: rpool-zvols:vm-299-disk-0, ~131.5G (134656M, resized live)
  disk {
    interface    = "virtio0"
    datastore_id = "rpool-zvols"
    size         = 132
    iothread     = true
    file_format  = "raw"
  }

  # virtio1: rpool-zvols:vm-299-disk-1, 64G (live-only, undeclared until now)
  disk {
    interface    = "virtio1"
    datastore_id = "rpool-zvols"
    size         = 64
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
  provider  = proxmox
  name      = "fipa"
  node_name = "node3"
  vm_id     = 389
  started   = false

  cpu {
    cores   = 4
    sockets = 1
    type    = "x86-64-v3"
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
  provider  = proxmox
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
  provider  = proxmox
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
  provider  = proxmox
  name      = "prod3-0"
  node_name = "node3"
  vm_id     = 8001
  started   = false

  cpu {
    cores   = 6
    sockets = 1
    type    = "x86-64-v3" # live: x86-64-v3 (drift-reconciled)
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
  provider  = proxmox
  node_name = "node3"
  vm_id     = 445
  started   = false # live: stopped (drift-reconciled)
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

  mount_point { # live: mp0 datapool0:445/vm-445-disk-0.raw, mp=/data, 4T (live-only, undeclared until now)
    volume = "datapool0"
    path   = "/data"
    size   = "4T"
  }

  network_interface {
    name        = "sf"
    bridge      = "vmbr2"
    firewall    = true
    mac_address = "D0:99:13:EB:54:10"
    vlan_id     = 3
  }

  network_interface { # live net1: bridge=node3 (live-only, undeclared until now)
    name        = "node3"
    bridge      = "node3"
    firewall    = true
    mac_address = "D0:99:13:08:60:74"
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
  provider  = proxmox
  node_name = "node3"
  vm_id     = 10389
  started   = false # live: stopped (drift-reconciled)

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

# LXC container for Ollama (Host AMD APU via passthrough)
resource "proxmox_virtual_environment_container" "node3_ollama" {
  provider     = proxmox
  node_name    = "node3"
  vm_id        = 114
  started      = true
  tags         = ["ollama", "llm", "apu"]
  unprivileged = false

  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
    type             = "debian"
  }

  cpu {
    cores = 4
  }

  memory {
    dedicated = 8192
  }

  disk {
    datastore_id = "rpool-zvols"
    size         = 30
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  initialization {
    hostname = "ollama-apu"
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  # AMD APU specific passthrough
  device_passthrough {
    path = "/dev/dri/renderD128"
  }
  device_passthrough {
    path = "/dev/kfd"
  }

  # Note: Required inside LXC to actually serve:
  # curl -fsSL https://ollama.com/install.sh | sh
  # systemctl edit ollama.service -> Environment="OLLAMA_HOST=0.0.0.0"
  # ollama pull nomic-embed-text
}
# node3_hermes (vm_id 9119) — live-unmanaged VM discovered during drift reconciliation.
# NOTE: `tofu import` for this resource failed with HTTP 403 (VM.Config.Disk) —
# the active API token lacks permission to read the VM's disk files. Config below
# is written from DRIFT.md live-inspection notes but is NOT yet imported into state.
# DO NOT `tofu apply` until either (a) import succeeds with a token that has
# VM.Config.Disk, or (b) this resource is confirmed absent from state — applying
# against an un-imported vm_id=9119 will attempt to create a duplicate VM.
resource "proxmox_virtual_environment_vm" "node3_hermes" {
  provider  = proxmox
  name      = "hermes"
  node_name = "node3"
  vm_id     = 9119
  started   = true
  on_boot   = true

  bios    = "ovmf"
  machine = "q35"

  cpu {
    cores   = 6
    sockets = 1
    type    = "x86-64-v3"
  }

  memory {
    dedicated = 6144
  }

  efi_disk {
    datastore_id = "rpool-zvols"
    type         = "4m"
  }

  disk {
    interface    = "virtio0"
    datastore_id = "rpool-zvols"
    size         = 100
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = "D0:99:13:6A:D8:A0"
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
