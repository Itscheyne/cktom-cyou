# ──────────────────────────────────────────────
# Longhorn — distributed block storage for Talos K8s
#
# Prerequisites (manual, outside Tofu):
#   - Talos node images built with extensions (see talos.tf schematic):
#       siderolabs/iscsi-tools
#       siderolabs/util-linux-tools
#   - kubeconfig available at var.longhorn_kubeconfig_path
#     (or set KUBE_CONFIG_PATH env var)
#
# Standalone: works without swamp.
#   tofu init && tofu apply \
#     -var="longhorn_kubeconfig_path=~/.kube/config"
# ──────────────────────────────────────────────

variable "longhorn_kubeconfig_path" {
  description = "Path to kubeconfig for the Talos cluster"
  type        = string
  default     = "~/.kube/config"
}

variable "longhorn_version" {
  description = "Longhorn Helm chart version"
  type        = string
  default     = "1.8.1"
}

variable "longhorn_replica_count" {
  description = "Default number of volume replicas (min 2 for HA)"
  type        = number
  default     = 2
}

variable "longhorn_storage_class_name" {
  description = "Name for the default Longhorn StorageClass"
  type        = string
  default     = "longhorn"
}

variable "longhorn_data_path" {
  description = "Path on each node where Longhorn stores volume data"
  type        = string
  default     = "/var/lib/longhorn"
}

# ── Providers ─────────────────────────────────

provider "helm" {
  kubernetes = {
    config_path = var.longhorn_kubeconfig_path
  }
}

provider "kubernetes" {
  config_path = var.longhorn_kubeconfig_path
}

# ── Namespace ─────────────────────────────────

resource "kubernetes_namespace_v1" "longhorn_system" {
  metadata {
    name = "longhorn-system"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

# ── Helm Release ──────────────────────────────

resource "helm_release" "longhorn" {
  name       = "longhorn"
  repository = "https://charts.longhorn.io"
  chart      = "longhorn"
  version    = var.longhorn_version
  namespace  = kubernetes_namespace_v1.longhorn_system.metadata[0].name

  wait            = true
  wait_for_jobs   = true
  timeout         = 600
  cleanup_on_fail = true

  # Talos: tolerate all taints so Longhorn daemonsets land on every node
  values = [
    yamlencode({
      tolerations = [{ operator = "Exists" }]
      longhornManager = {
        tolerations = [{ operator = "Exists" }]
      }
      longhornDriver = {
        tolerations = [{ operator = "Exists" }]
      }
    })
  ]

  set = [
    {
      name  = "defaultSettings.defaultReplicaCount"
      value = tostring(var.longhorn_replica_count)
      type  = "string"
    },
    {
      name  = "defaultSettings.defaultDataPath"
      value = var.longhorn_data_path
      type  = "string"
    },
    {
      name  = "defaultSettings.createDefaultDiskLabeledNodes"
      value = "false"
      type  = "string"
    },
    # Disable chart-managed StorageClass — managed explicitly below
    {
      name  = "persistence.defaultClass"
      value = "false"
      type  = "string"
    },
    {
      name  = "persistence.defaultClassReplicaCount"
      value = tostring(var.longhorn_replica_count)
      type  = "string"
    },
    {
      name  = "persistence.defaultFsType"
      value = "ext4"
      type  = "string"
    },
  ]

  depends_on = [kubernetes_namespace_v1.longhorn_system]
}

# ── StorageClass ──────────────────────────────

resource "kubernetes_storage_class_v1" "longhorn_default" {
  metadata {
    name = var.longhorn_storage_class_name
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "driver.longhorn.io"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "Immediate"
  allow_volume_expansion = true

  parameters = {
    numberOfReplicas    = tostring(var.longhorn_replica_count)
    dataLocality        = "disabled"
    fromBackup          = ""
    fsType              = "ext4"
    migratable          = "true"
    dataEngine          = "v1"
    staleReplicaTimeout = "30"
  }

  depends_on = [helm_release.longhorn]
}

# ── Outputs ───────────────────────────────────

output "longhorn_namespace" {
  value = kubernetes_namespace_v1.longhorn_system.metadata[0].name
}

output "longhorn_chart_version" {
  value = helm_release.longhorn.version
}

output "longhorn_storage_class" {
  value = kubernetes_storage_class_v1.longhorn_default.metadata[0].name
}

output "longhorn_ui_instructions" {
  value = "kubectl -n longhorn-system port-forward svc/longhorn-frontend 8080:80"
}
