# --- Image Factory schematic (netbird extension) ---

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = [
          "siderolabs/iscsi-tools",
          "siderolabs/netbird",
          "siderolabs/qemu-guest-agent",
          "siderolabs/util-linux-tools",
        ]
      }
    }
  })
}

# --- Download Talos ISO to node1 ---

resource "proxmox_download_file" "talos_iso_node1" {
  provider     = proxmox
  node_name    = "node1"
  content_type = "iso"
  datastore_id = "local"

  url       = "https://factory.talos.dev/image/${talos_image_factory_schematic.this.id}/${var.talos_version}/nocloud-amd64.iso"
  file_name = "talos-${var.talos_version}-netbird-nocloud-v6.iso"

  overwrite = true
}

# --- Talos machine secrets (cluster CA, etcd certs, etc.) ---

resource "talos_machine_secrets" "cluster" {
  talos_version = var.talos_version
}

# --- SDN node1 IPs ---

locals {
  sdn_gateway = "192.168.111.1"
  cp_ip       = "192.168.111.6"
}

# --- Machine configuration patches (common) ---

locals {
  common_patches = [
    # Install disk and image
    yamlencode({
      machine = {
        install = {
          disk  = "/dev/vda"
          image = "factory.talos.dev/installer/${talos_image_factory_schematic.this.id}:${var.talos_version}"
        }
        # Netbird extension config
        files = [
          {
            path        = "/var/etc/netbird/config.json"
            permissions = 0
            op          = "create"
            content     = ""
          }
        ]
      }
    }),
    # Netbird ExtensionServiceConfig
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "ExtensionServiceConfig"
      name       = "netbird"
      environment = concat(
        ["NB_SETUP_KEY=${var.talos_netbird_setup_key}"],
        var.talos_netbird_management_url != "" ? [
          "NB_MANAGEMENT_URL=${var.talos_netbird_management_url}",
          "NB_ADMIN_URL=${var.talos_netbird_management_url}",
        ] : []
      )
    }),
  ]
}

# --- Control-plane machine configuration ---

data "talos_machine_configuration" "cp" {
  cluster_name     = var.talos_cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = "https://${local.cp_ip}:6443"
  machine_secrets  = talos_machine_secrets.cluster.machine_secrets

  config_patches = concat(local.common_patches, [
    # Allow control-plane to schedule workloads (single-node cluster)
    yamlencode({
      cluster = {
        allowSchedulingOnControlPlanes = true
      }
    }),
    # Static IP config for node1 SDN
    yamlencode({
      machine = {
        network = {
          interfaces = [
            {
              interface = "ens18"
              addresses = ["${local.cp_ip}/24"]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = local.sdn_gateway
                }
              ]
            }
          ]
        }
      }
    })
  ])
}

# --- Control-plane VM on node1 ---

resource "proxmox_virtual_environment_vm" "talos_cp" {
  provider  = proxmox
  name      = "talos-cp1"
  node_name = "node1"
  vm_id     = 8000

  started       = true
  on_boot       = true
  machine       = "q35"
  bios          = "ovmf"
  tablet_device = false

  cpu {
    cores   = 8
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
    interface    = "virtio0"
    datastore_id = "imagepool-zvols"
    size         = 100
    iothread     = true
    discard      = "on"
    file_format  = "raw"
  }

  cdrom {
    enabled   = true
    file_id   = proxmox_download_file.talos_iso_node1.id
    interface = "ide0"
  }

  network_device {
    bridge = "node1"
    model  = "virtio"
  }

  boot_order = ["ide0", "virtio0"]

  initialization {
    type         = "nocloud"
    datastore_id = "local"
    ip_config {
      ipv4 {
        address = "${local.cp_ip}/24"
        gateway = local.sdn_gateway
      }
    }
  }

  operating_system {
    type = "l26"
  }

  agent {
    enabled = true
  }
}

# --- Apply machine configuration ---

resource "talos_machine_configuration_apply" "cp" {
  depends_on = [proxmox_virtual_environment_vm.talos_cp]

  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = data.talos_machine_configuration.cp.machine_configuration
  node                        = local.cp_ip

  lifecycle {
    replace_triggered_by = [
      talos_machine_secrets.cluster,
    ]
  }
}

# --- Bootstrap etcd ---

resource "talos_machine_bootstrap" "cp" {
  depends_on = [talos_machine_configuration_apply.cp]

  client_configuration = talos_machine_secrets.cluster.client_configuration
  node                 = local.cp_ip
}

# --- Kubeconfig output ---

resource "talos_cluster_kubeconfig" "cluster" {
  depends_on = [talos_machine_bootstrap.cp]

  client_configuration = talos_machine_secrets.cluster.client_configuration
  node                 = local.cp_ip
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.cluster.kubeconfig_raw
  sensitive = true
}

output "talosconfig" {
  value     = data.talos_client_configuration.cluster.talos_config
  sensitive = true
}

# --- talosctl client config ---

data "talos_client_configuration" "cluster" {
  cluster_name         = var.talos_cluster_name
  client_configuration = talos_machine_secrets.cluster.client_configuration
  nodes                = [local.cp_ip]
  endpoints            = [local.cp_ip]
}
