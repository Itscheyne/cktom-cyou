# ──────────────────────────────────────────────
# node1 - Proxmox Host
# GPU node: 2x PCIe GPUs, IOMMU enabled
#
# ZFS pools: rpool, datapool, imagepool
# Storage backends: rpool-zvols, imagepool-zvols, datapool-zvols,
#                   rpool (dir), imagepool (dir), datapool (dir),
#                   rpool-dir, imagepool, datapool
# ──────────────────────────────────────────────

# ── Running VMs ──────────────────────────────

resource "proxmox_virtual_environment_vm" "node1_llama" {
  provider  = proxmox.node1
  name      = "VM-llama"
  node_name = "node1"
  vm_id     = 100
  started   = true
  tags      = ["gpu"]

  cpu {
    cores   = 6
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = 16384
  }

  efi_disk {
    datastore_id = "rpool"
    type         = "4m"
  }

  disk {
    interface    = "scsi0"
    datastore_id = "imagepool-zvols"
    size         = 256
    iothread     = true
    file_format  = "raw"
  }

  disk {
    interface    = "scsi1"
    datastore_id = "imagepool-zvols"
    size         = 128
    iothread     = true
    discard      = "on"
    file_format  = "raw"
  }

  disk {
    interface    = "scsi2"
    datastore_id = "datapool-zvols"
    size         = 1024
    iothread     = true
    file_format  = "raw"
  }

  disk {
    interface    = "scsi3"
    datastore_id = "datapool-zvols"
    size         = 256
    iothread     = true
    file_format  = "raw"
  }

  # virtio0: imagepool-zvols:vm-100-disk-4, 300G
  disk {
    interface    = "virtio0"
    datastore_id = "imagepool-zvols"
    size         = 300
    iothread     = true
    discard      = "on"
    file_format  = "raw"
  }

  network_device {
    bridge      = "node1"
    mac_address = "BC:24:11:EE:E2:95"
    model       = "virtio"
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_vm" "node1_dockbox" {
  provider  = proxmox.node1
  name      = "dockbox"
  node_name = "node1"
  vm_id     = 2000
  started   = true
  tags      = ["docker", "gpu"]

  cpu {
    cores   = 6
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = 16384
  }

  efi_disk {
    datastore_id = "rpool"
    type         = "4m"
  }

  disk {
    interface    = "scsi0"
    datastore_id = "imagepool-zvols"
    size         = 128
    iothread     = true
    discard      = "on"
    file_format  = "raw"
  }

  disk {
    interface    = "scsi1"
    datastore_id = "datapool-zvols"
    size         = 1024
    iothread     = true
    discard      = "on"
    file_format  = "raw"
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = "BC:24:11:F7:D7:AA"
    model       = "virtio"
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_vm" "node1_prod1" {
  provider  = proxmox.node1
  name      = "prod1"
  node_name = "node1"
  vm_id     = 1001
  started   = true

  cpu {
    cores   = 4
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = 4096
  }

  efi_disk {
    datastore_id = "rpool"
    type         = "4m"
  }

  disk {
    interface    = "virtio0"
    datastore_id = "imagepool-zvols"
    size         = 20
    iothread     = true
    discard      = "on"
    file_format  = "raw"
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = "BC:24:11:D5:82:73"
    model       = "virtio"
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

# ── Stopped VMs ──────────────────────────────

resource "proxmox_virtual_environment_vm" "node1_dev" {
  provider  = proxmox.node1
  name      = "dev"
  node_name = "node1"
  vm_id     = 299
  started   = false

  cpu {
    cores   = 6
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = 12414
  }

  efi_disk {
    datastore_id = "rpool"
    type         = "4m"
  }

  disk {
    interface    = "virtio0"
    datastore_id = "imagepool-zvols"
    size         = 128
    iothread     = true
    file_format  = "raw"
  }

  network_device {
    bridge      = "node1"
    mac_address = "BC:24:11:CF:90:78"
    model       = "virtio"
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_vm" "node1_dev_node1" {
  provider  = proxmox.node1
  name      = "dev-node1"
  node_name = "node1"
  vm_id     = 1000
  started   = false

  cpu {
    cores   = 6
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = 16384
  }

  efi_disk {
    datastore_id = "rpool"
    type         = "4m"
  }

  disk {
    interface    = "scsi0"
    datastore_id = "imagepool-zvols"
    size         = 160
    iothread     = true
    discard      = "on"
    file_format  = "raw"
  }

  network_device {
    bridge      = "node1"
    mac_address = "BC:24:11:04:85:2A"
    model       = "virtio"
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_vm" "node1_sockpot" {
  provider  = proxmox.node1
  name      = "sockpot"
  node_name = "node1"
  vm_id     = 1071
  started   = false

  cpu {
    cores   = 2
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = 3072
  }

  disk {
    interface    = "scsi0"
    datastore_id = "imagepool-zvols"
    size         = 32
    iothread     = true
    file_format  = "raw"
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = "BC:24:11:C8:11:24"
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

resource "proxmox_virtual_environment_vm" "node1_vllm" {
  provider  = proxmox.node1
  name      = "vllm"
  node_name = "node1"
  vm_id     = 2001
  started   = false

  cpu {
    cores   = 6
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = 16384
  }

  efi_disk {
    datastore_id = "imagepool"
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
    bridge      = "vmbr0"
    mac_address = "BC:24:11:80:CF:F4"
    model       = "virtio"
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = all
  }
}

# ── Templates ─────────────────────────────────

resource "proxmox_virtual_environment_vm" "node1_template_fedora_iot" {
  provider  = proxmox.node1
  name      = "template-fedora-iot-base"
  node_name = "node1"
  vm_id     = 9999
  started   = false
  template  = true
  tags      = ["cloudinit", "fedora", "template"]

  cpu {
    cores   = 4
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = 4096
  }

  efi_disk {
    datastore_id = "imagepool-zvols"
    type         = "4m"
  }

  disk {
    interface    = "scsi0"
    datastore_id = "imagepool-zvols"
    size         = 24
    iothread     = true
    file_format  = "raw"
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = "BC:24:11:CF:2E:89"
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

resource "proxmox_virtual_environment_vm" "node1_flustercuck0" {
  provider  = proxmox.node1
  name      = "flustercuck0"
  node_name = "node1"
  vm_id     = 10000
  started   = false
  tags      = ["talos", "controlplane"]

  cpu {
    cores   = 4
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = 4096
  }

  efi_disk {
    datastore_id = "datapool"
    type         = "4m"
  }

  disk {
    interface    = "scsi0"
    datastore_id = "imagepool-zvols"
    size         = 16
    iothread     = true
    discard      = "on"
    file_format  = "raw"
  }

  disk {
    interface    = "scsi1"
    datastore_id = "imagepool-zvols"
    size         = 64
    iothread     = true
    discard      = "on"
    file_format  = "raw"
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = "BC:24:11:A7:53:54"
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

resource "proxmox_virtual_environment_vm" "node1_flustercuck1" {
  provider  = proxmox.node1
  name      = "flustercuck1"
  node_name = "node1"
  vm_id     = 10001
  started   = false
  tags      = ["talos"]

  cpu {
    cores   = 4
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = 4092
  }

  efi_disk {
    datastore_id = "rpool"
    type         = "4m"
  }

  disk {
    interface    = "scsi0"
    datastore_id = "imagepool-zvols"
    size         = 64
    iothread     = true
    discard      = "on"
    file_format  = "raw"
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = "BC:24:11:7D:CB:29"
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

# ── LXC Containers ───────────────────────────

resource "proxmox_virtual_environment_container" "node1_stash0" {
  provider  = proxmox.node1
  node_name = "node1"
  vm_id     = 103
  started   = false

  cpu {
    cores = 6
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = "datapool-dir"
    size         = 16
  }

  operating_system {
    template_file_id = "local:vztmpl/placeholder.tar.xz"
    type             = "centos"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_container" "node1_stash" {
  provider  = proxmox.node1
  node_name = "node1"
  vm_id     = 111
  started   = false

  cpu {
    cores = 5
  }

  memory {
    dedicated = 3072
  }

  disk {
    datastore_id = "imagepool-zvols"
    size         = 26
  }

  operating_system {
    template_file_id = "local:vztmpl/placeholder.tar.xz"
    type             = "centos"
  }

  lifecycle {
    ignore_changes = all
  }
}
