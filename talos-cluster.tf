resource "talos_machine_secrets" "cluster" {
  talos_version = var.talos_version
}

locals {
  # CPs
  node3_cp_ips = {
    for k, v in module.node3.talos_node3_cp_ips : k => try([for ip in flatten(v) : ip if ip != "127.0.0.1" && !can(regex("^::1$|^fe80", ip))][0], "")
  }
  node4_cp_ips = {
    for k, v in module.node4.talos_node4_cp_ips : k => try([for ip in flatten(v) : ip if ip != "127.0.0.1" && !can(regex("^::1$|^fe80", ip))][0], "")
  }
  all_cp_ips = merge(local.node3_cp_ips, local.node4_cp_ips)

  # Workers
  node3_worker_ips = {
    for k, v in module.node3.talos_node3_worker_ips : k => try([for ip in flatten(v) : ip if ip != "127.0.0.1" && !can(regex("^::1$|^fe80", ip))][0], "")
  }
  node4_worker_ips = {
    for k, v in module.node4.talos_node4_worker_ips : k => try([for ip in flatten(v) : ip if ip != "127.0.0.1" && !can(regex("^::1$|^fe80", ip))][0], "")
  }
  all_worker_ips = merge(local.node3_worker_ips, local.node4_worker_ips)

  endpoint_ip            = local.all_cp_ips["cp1"] != "" ? local.all_cp_ips["cp1"] : "127.0.0.1"
  talos_cluster_endpoint = "https://${local.endpoint_ip}:6443"
  install_disk           = "/dev/sda"
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
          image = "factory.talos.dev/installer/${var.talos_version}"
        }
      }
      cluster = {
        network = {
          cni = {
            name = "none"
          }
        }
      }
    })
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
          image = "factory.talos.dev/installer/${var.talos_version}"
        }
      }
    })
  ]
}

resource "talos_machine_configuration_apply" "controlplane" {
  for_each                    = local.all_cp_ips
  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = each.value
}

resource "talos_machine_configuration_apply" "worker" {
  for_each                    = local.all_worker_ips
  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = each.value
}

resource "talos_machine_bootstrap" "this" {
  depends_on           = [talos_machine_configuration_apply.controlplane]
  client_configuration = talos_machine_secrets.cluster.client_configuration
  node                 = local.endpoint_ip
}

resource "talos_cluster_kubeconfig" "cluster" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.cluster.client_configuration
  node                 = local.endpoint_ip
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.cluster.kubeconfig_raw
  sensitive = true
}
