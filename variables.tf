variable "proxmox_insecure" {
  description = "Skip TLS verification for self-signed certificates"
  type        = bool
  default     = true
}

variable "node1_endpoint" {
  description = "Proxmox VE API endpoint for node1 (e.g. https://node1.lab.hi.cktom.cyou:8006)"
  type        = string
}

variable "node1_username" {
  description = "Proxmox VE API username for node1 (e.g. root@pam)"
  type        = string
}

variable "node1_password" {
  description = "Proxmox VE API password for node1"
  type        = string
  sensitive   = true
}

variable "node3_endpoint" {
  description = "Proxmox VE API endpoint for node3 (e.g. https://node3.lab.sf.cktom.cyou:8006)"
  type        = string
}

variable "node3_username" {
  description = "Proxmox VE API username for node3 (e.g. root@pam)"
  type        = string
}

variable "node3_password" {
  description = "Proxmox VE API password for node3"
  type        = string
  sensitive   = true
}

variable "node4_endpoint" {
  description = "Proxmox VE API endpoint for node4 (e.g. https://node4.lab.sf.cktom.cyou:8006)"
  type        = string
}

variable "node4_username" {
  description = "Proxmox VE API username for node4 (e.g. root@pam)"
  type        = string
}

variable "node4_password" {
  description = "Proxmox VE API password for node4"
  type        = string
  sensitive   = true
}

variable "talos_cluster_name" {
  description = "Talos cluster name (used in kubeconfig and cluster certs)"
  type        = string
  default     = "cktom"
}

variable "talos_version" {
  description = "Talos version to deploy (e.g. v1.13.2)"
  type        = string
  default     = "v1.13.2"
}

variable "talos_cp_netbird_ip" {
  description = "Netbird VPN IP of the control-plane node — set after first boot, used as cluster_endpoint"
  type        = string
  default     = ""
}

variable "talos_netbird_setup_key" {
  description = "Netbird peer setup key for the Talos control-plane node"
  type        = string
  sensitive   = true
}

variable "talos_netbird_management_url" {
  description = "Netbird management URL (leave empty for cloud)"
  type        = string
  default     = ""
}

variable "talos_worker_node1_ip" {
  description = "Initial DHCP IP or Netbird IP of the worker node on node1"
  type        = string
  default     = ""
}

variable "talos_worker_node3_ip" {
  description = "Initial DHCP IP or Netbird IP of the worker node on node3"
  type        = string
  default     = ""
}

variable "talos_worker_node4_ip" {
  description = "Initial DHCP IP or Netbird IP of the worker node on node4"
  type        = string
  default     = ""
}
