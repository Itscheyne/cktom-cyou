# ArgoCD — GitOps continuous delivery, deployed onto the talos-cluster
# (node3 controlplane / node4 worker) bootstrapped in talos-cluster.tf.
#
# Providers wire off the freshly-bootstrapped cluster's
# kubernetes_client_configuration (talos_cluster_kubeconfig.cluster), not a
# static kubeconfig file, so `tofu apply` can run straight through from VM
# creation -> Talos bootstrap -> ArgoCD install without any manual kubeconfig
# handoff. Cert/key fields come back base64-encoded from the talos provider;
# both hashicorp/helm and hashicorp/kubernetes expect raw PEM.

provider "helm" {
  kubernetes = {
    host                   = talos_cluster_kubeconfig.cluster.kubernetes_client_configuration.host
    client_certificate     = base64decode(talos_cluster_kubeconfig.cluster.kubernetes_client_configuration.client_certificate)
    client_key             = base64decode(talos_cluster_kubeconfig.cluster.kubernetes_client_configuration.client_key)
    cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.cluster.kubernetes_client_configuration.ca_certificate)
  }
}

provider "kubernetes" {
  host                   = talos_cluster_kubeconfig.cluster.kubernetes_client_configuration.host
  client_certificate     = base64decode(talos_cluster_kubeconfig.cluster.kubernetes_client_configuration.client_certificate)
  client_key             = base64decode(talos_cluster_kubeconfig.cluster.kubernetes_client_configuration.client_key)
  cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.cluster.kubernetes_client_configuration.ca_certificate)
}

variable "argocd_chart_version" {
  description = "argo-cd Helm chart version (argoproj/argo-helm)"
  type        = string
  default     = "10.9.2" # app version v3.5.3
}

variable "argocd_namespace" {
  description = "Kubernetes namespace ArgoCD is installed into"
  type        = string
  default     = "argocd"
}

resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = var.argocd_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name

  # Single-node cluster (node3 CP / node4 worker, no HA) -> disable HA
  # components (redis-ha, extra controller replicas) the chart would
  # otherwise schedule; they can't find enough nodes to satisfy anti-affinity.
  values = [
    yamlencode({
      redis-ha = {
        enabled = false
      }
      controller = {
        replicas = 1
      }
      server = {
        replicas = 1
      }
      repoServer = {
        replicas = 1
      }
      applicationSet = {
        replicaCount = 1
      }
    })
  ]

  # Wait for the chart's resources to actually roll out (deployments
  # Available, etc.) instead of just accepting the API objects.
  wait          = true
  wait_for_jobs = true
  timeout       = 600

  atomic = true
}
