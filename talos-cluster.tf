# Talos Kubernetes cluster bootstrap: node3 = controlplane, node4 = worker.
# Only 2 physical hosts exist -> single control-plane node (2-node etcd quorum is
# unsafe, so we don't attempt HA here). VMs themselves are provisioned in
# modules/node3/talos.tf and modules/node4/talos.tf (vm_id 810 / 811); this file
# owns the shared cluster identity + machine config + bootstrap, which must live
# at root (single instance, not duplicated per node module).

resource "talos_machine_secrets" "cluster" {
  talos_version = var.talos_version
}

locals {
  # Both talos VMs sit on the untagged/native vlan of vmbr0 (shared upstream LAN,
  # DHCP), NOT the per-node SDN NAT zones (10.13.0.0/24 / 10.14.0.0/24 are
  # node-isolated and not mutually routable, so they can't carry cluster traffic).
  # ipv4_addresses is List(List(String)) per network interface; index 0 is
  # lo/127.0.0.1. Filter that out (and any ipv6/link-local noise) to get the
  # real DHCP-assigned address reported by qemu-guest-agent.
  node3_ip = try(
    [for ip in flatten(module.node3.talos_node3_ips) : ip
      if ip != "127.0.0.1" && !can(regex("^::1$|^fe80", ip))
    ][0],
    null
  )
  node4_ip = try(
    [for ip in flatten(module.node4.talos_node4_ips) : ip
      if ip != "127.0.0.1" && !can(regex("^::1$|^fe80", ip))
    ][0],
    null
  )

  talos_cluster_endpoint = "https://${local.node3_ip}:6443"

  # scsi0 is the first (and only) data disk on both VMs under the default
  # virtio-scsi-pci controller -> exposed to the guest as /dev/sda.
  install_disk = "/dev/sda"
}

data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.talos_cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = local.talos_cluster_endpoint
  talos_version    = var.talos_version
  machine_secrets  = talos_machine_secrets.cluster.machine_secrets

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk  = local.install_disk
          image = module.node3.node3_talos_installer_image
        }
      }
    }),
  ]
}

data "talos_machine_configuration" "worker" {
  cluster_name     = var.talos_cluster_name
  machine_type     = "worker"
  cluster_endpoint = local.talos_cluster_endpoint
  talos_version    = var.talos_version
  machine_secrets  = talos_machine_secrets.cluster.machine_secrets

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk  = local.install_disk
          image = module.node4.node4_talos_installer_image
        }
      }
    }),
  ]
}

resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = local.node3_ip

  lifecycle {
    replace_triggered_by = [talos_machine_secrets.cluster]
  }
}

resource "talos_machine_configuration_apply" "worker" {
  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = local.node4_ip

  lifecycle {
    replace_triggered_by = [talos_machine_secrets.cluster]
  }
}

resource "talos_machine_bootstrap" "controlplane" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  client_configuration = talos_machine_secrets.cluster.client_configuration
  node                 = local.node3_ip
}

resource "talos_cluster_kubeconfig" "cluster" {
  depends_on = [talos_machine_bootstrap.controlplane]

  client_configuration = talos_machine_secrets.cluster.client_configuration
  node                 = local.node3_ip
}

data "talos_client_configuration" "cluster" {
  cluster_name         = var.talos_cluster_name
  client_configuration = talos_machine_secrets.cluster.client_configuration
  nodes                = [local.node3_ip, local.node4_ip]
  endpoints            = [local.node3_ip]
}

output "kubeconfig" {
  description = "Kubeconfig for the talos-cluster (node3 CP / node4 worker)"
  value       = talos_cluster_kubeconfig.cluster.kubeconfig_raw
  sensitive   = true
}

output "talosconfig" {
  description = "Talosctl client config for the talos-cluster"
  value       = data.talos_client_configuration.cluster.talos_config
  sensitive   = true
}
