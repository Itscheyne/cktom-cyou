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

resource "kubernetes_namespace_v1" "longhorn_system" {
  metadata {
    name = "longhorn-system"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

resource "helm_release" "longhorn" {
  name       = "longhorn"
  repository = "https://charts.longhorn.io"
  chart      = "longhorn"
  version    = var.longhorn_version
  namespace  = kubernetes_namespace_v1.longhorn_system.metadata[0].name

  set {
    name  = "persistence.defaultClassReplicaCount"
    value = var.longhorn_replica_count
  }

  set {
    name  = "persistence.defaultClass"
    value = "true"
  }

  set {
    name  = "defaultSettings.defaultDataPath"
    value = var.longhorn_data_path
  }
}
