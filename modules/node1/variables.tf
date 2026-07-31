# Talos inputs — passed from root.

variable "talos_version" {
  description = "Talos version to deploy (e.g. v1.13.3)"
  type        = string
}

variable "talos_cluster_name" {
  description = "Talos cluster name"
  type        = string
}

variable "talos_netbird_setup_key" {
  description = "Netbird peer setup key for Talos nodes"
  type        = string
  sensitive   = true
}

variable "talos_netbird_management_url" {
  description = "Netbird management URL (leave empty for cloud default)"
  type        = string
}
