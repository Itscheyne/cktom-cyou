variable "talos_version" {
  description = "Talos OS version"
  type        = string
  default     = "v1.7.0"
}

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = [
          "siderolabs/qemu-guest-agent",
        ]
      }
    }
  })
}

resource "proxmox_download_file" "talos_iso_node3" {
  provider     = proxmox
  node_name    = "node3"
  content_type = "iso"
  datastore_id = "local"
  url          = "https://factory.talos.dev/image/${talos_image_factory_schematic.this.id}/${var.talos_version}/nocloud-amd64.iso"
  file_name    = "talos-${var.talos_version}-qemuga.iso"
  overwrite    = false
}

resource "proxmox_virtual_environment_vm" "talos_cp" {
  provider = proxmox
  for_each = {
    "cp1" = { id = 810, mac = "BC:24:11:A3:33:10" }
    "cp2" = { id = 811, mac = "BC:24:11:A3:33:11" }
  }

  name      = "talos-node3-${each.key}"
  node_name = "node3"
  vm_id     = each.value.id
  started   = true
  tags      = ["talos", "controlplane"]

  agent { enabled = true }
  cpu {
    cores = 2
    type  = "host"
  }
  memory { dedicated = 2048 }

  efi_disk {
    datastore_id = "datapool0"
    type         = "4m"
  }
  cdrom { file_id = proxmox_download_file.talos_iso_node3.id }

  disk {
    interface    = "scsi0"
    datastore_id = "datapool0-zvols"
    size         = 32
    iothread     = true
    discard      = "on"
    file_format  = "raw"
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = each.value.mac
    model       = "virtio"
    firewall    = true
  }

  operating_system { type = "l26" }

  initialization {
    ip_config {
      ipv4 { address = "dhcp" }
    }
  }

  boot_order = ["cdrom", "scsi0"]

  lifecycle {
    ignore_changes = [initialization]
  }
}

resource "proxmox_virtual_environment_vm" "talos_worker" {
  provider = proxmox
  for_each = {
    "worker1" = { id = 820, mac = "BC:24:11:A3:33:20" }
    "worker2" = { id = 821, mac = "BC:24:11:A3:33:21" }
  }

  name      = "talos-node3-${each.key}"
  node_name = "node3"
  vm_id     = each.value.id
  started   = true
  tags      = ["talos", "worker"]

  agent { enabled = true }
  cpu {
    cores = 4
    type  = "host"
  }
  memory { dedicated = 24576 }

  efi_disk {
    datastore_id = "datapool0"
    type         = "4m"
  }
  cdrom { file_id = proxmox_download_file.talos_iso_node3.id }

  disk {
    interface    = "scsi0"
    datastore_id = "datapool0-zvols"
    size         = 100
    iothread     = true
    discard      = "on"
    file_format  = "raw"
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = each.value.mac
    model       = "virtio"
    firewall    = true
  }

  operating_system { type = "l26" }

  initialization {
    ip_config {
      ipv4 { address = "dhcp" }
    }
  }

  boot_order = ["cdrom", "scsi0"]

  lifecycle {
    ignore_changes = [initialization]
  }
}

output "talos_node3_cp_ips" {
  value = { for k, v in proxmox_virtual_environment_vm.talos_cp : k => v.ipv4_addresses }
}

output "talos_node3_worker_ips" {
  value = { for k, v in proxmox_virtual_environment_vm.talos_worker : k => v.ipv4_addresses }
}
