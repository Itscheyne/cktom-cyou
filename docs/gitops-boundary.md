# GitOps Architecture Boundary

This document defines the separation of concerns between our Infrastructure as Code (IaC) pipeline and our Application continuous delivery pipeline. 

## The Dual-Pipeline Architecture

We utilize a two-tier approach to cluster management to ensure strict separation between infrastructure provisioning and workload lifecycle management:

1. **Infrastructure CI Pipeline (OpenTofu via GitHub Actions)**
2. **Application GitOps Pipeline (ArgoCD)**

---

## 1. OpenTofu / Infrastructure CI (The "Underlay")

OpenTofu is strictly responsible for providing the runtime environment. It provisions the compute, storage, orchestration engines, and installs the required platform controllers (the "Day 0" and "Day 1" operations). 

**Managed exclusively by OpenTofu:**
- **Proxmox Infrastructure:** VMs, LXC containers, SDN Vnets, bridges, and Storage Pools (ZFS/LVM).
- **Network Boundaries:** NetBird VPN topology, static IP assignments, and infrastructure-level routing.
- **Operating Systems:** Cloud-init configs, VM bootstrapping, and Base OS configurations.
- **Talos Kubernetes Cluster Bootstrap:** Node generation, machine configs, `talosconfig`, and `kubeconfig` synthesis.
- **Core Platform Controllers:** Helm/Kubernetes deployments of foundational cluster components that must exist before the cluster can pull its workloads:
  - ArgoCD itself (via `argocd.tf`)
  - Longhorn (or primary CSI driver) if it is treated as a cluster primitive.

**Rule of Thumb:** If it runs *underneath* Kubernetes or is required for Kubernetes to boot up and fetch its workloads, OpenTofu manages it. OpenTofu stops at the workload boundary.

---

## 2. ArgoCD / Application GitOps (The "Overlay")

ArgoCD is responsible for application workloads, user-facing services, and non-core operational components (the "Day 2" operations). Once OpenTofu yields a healthy cluster with ArgoCD installed, ArgoCD takes over the rest.

**Managed exclusively by ArgoCD:**
- **Microservices & Web Applications:** Deployments, StatefulSets, DaemonSets, and CronJobs that form the actual apps.
- **Service Mesh & API Gateways:** Ingress controllers (like Nginx or Traefik), and cert-manager certs.
- **Observability Stack Workloads:** Prometheus, Grafana, Loki (components running inside K8s, distinct from host-level Netdata which is deployed differently).
- **Cluster Configurations (Post-Boot):** NetworkPolicies, RBAC, ConfigMaps, and Secrets for application workloads.

**Rule of Thumb:** If it is a generic Kubernetes YAML manifest or Helm chart representing an application/service sitting on top of the cluster API, ArgoCD manages it. OpenTofu should have zero awareness of these deployments.

---

## The Hand-off Process

1. **OpenTofu CI triggers** on main branch merge.
2. OpenTofu requests new VMs from Proxmox.
3. OpenTofu generates Talos configurations and applies them to form the cluster.
4. Talos provides an exposed standard `kubeconfig`.
5. OpenTofu uses the Kubernetes/Helm providers to inject ArgoCD into the cluster (and applies the "App of Apps" pattern root Application if defined).
6. **Hand-off complete.** OpenTofu's state tracks *ArgoCD's existence*, not ArgoCD's sub-deployments.
7. ArgoCD syncs the target Git repository looking for application manifests.
8. Any subsequent application change only triggers an ArgoCD sync, bypassing the OpenTofu GitHub Action pipeline.

## Why this Split?

- **Reduced Blast Radius:** An invalid application manifest cannot crash the entire OpenTofu state file or accidentally destroy a VM.
- **Velocity:** Application engineers submit PRs that seamlessly sync in seconds via ArgoCD without waiting for minutes-long `tofu plan` CI jobs to resolve Proxmox state.
- **Drift Protection:** OpenTofu isn't constantly fighting Kubernetes mutating webhooks over API fields (ArgoCD natively understands Kubernetes server-side apply and sync waves).
