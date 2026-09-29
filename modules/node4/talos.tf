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

resource "proxmox_download_file" "talos_iso_node4" {
  provider     = proxmox
  node_name    = "node4"
  content_type = "iso"
  datastore_id = "local"

  url       = "https://factory.talos.dev/image/${talos_image_factory_schematic.this.id}/${var.talos_version}/nocloud-amd64.iso"
  file_name = "talos-${var.talos_version}-qemuga.iso"
  overwrite = true
}

resource "proxmox_virtual_environment_vm" "node4_talos_node" {
  provider  = proxmox
  name      = "talos-node4-k8s"
  node_name = "node4"
  vm_id     = 811
  started   = true
  tags      = ["talos", "worker"]

  agent {
    enabled = true
  }

  cpu {
    cores   = 4
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = 8192
  }

  efi_disk {
    datastore_id = "imagepool0"
    type         = "4m"
  }

  cdrom {
    file_id = proxmox_download_file.talos_iso_node4.id
  }

  disk {
    interface    = "scsi0"
    datastore_id = "imagepool0-zvols"
    size         = 64
    iothread     = true
    discard      = "on"
    file_format  = "raw"
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = "BC:24:11:A4:44:02"
    model       = "virtio"
    firewall    = true
  }

  operating_system {
    type = "l26"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  boot_order = ["cdrom", "scsi0", "net0"]

  lifecycle {
    ignore_changes = all
  }
}

output "talos_node4_ips" {
  value = proxmox_virtual_environment_vm.node4_talos_node.ipv4_addresses
}

output "node4_talos_installer_image" {
  description = "Talos installer image ref matching this node's factory schematic + version"
  value       = "factory.talos.dev/installer/${talos_image_factory_schematic.this.id}:${var.talos_version}"
}
