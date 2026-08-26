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
  default     = null
}

variable "node1_password" {
  description = "Proxmox VE API password for node1"
  type        = string
  sensitive   = true
  default     = null
}

variable "node1_api_token" {
  description = "Proxmox VE API token for node1 (e.g. ghprod@pve!apply=<secret>). Takes precedence over password when set."
  type        = string
  sensitive   = true
  default     = null
}

variable "node3_endpoint" {
  description = "Proxmox VE API endpoint for node3 (e.g. https://node3.lab.sf.cktom.cyou:8006)"
  type        = string
}

variable "node3_username" {
  description = "Proxmox VE API username for node3 (e.g. root@pam)"
  type        = string
  default     = null
}

variable "node3_password" {
  description = "Proxmox VE API password for node3"
  type        = string
  sensitive   = true
  default     = null
}

variable "node3_api_token" {
  description = "Proxmox VE API token for node3 (e.g. ghprod@pve!apply=<secret>). Takes precedence over password when set."
  type        = string
  sensitive   = true
  default     = null
}

variable "node4_endpoint" {
  description = "Proxmox VE API endpoint for node4 (e.g. https://node4.lab.sf.cktom.cyou:8006)"
  type        = string
}

variable "node4_username" {
  description = "Proxmox VE API username for node4 (e.g. root@pam)"
  type        = string
  default     = null
}

variable "node4_password" {
  description = "Proxmox VE API password for node4"
  type        = string
  sensitive   = true
  default     = null
}

variable "node4_api_token" {
  description = "Proxmox VE API token for node4 (e.g. ghprod@pve!apply=<secret>). Takes precedence over password when set."
  type        = string
  sensitive   = true
  default     = null
}

variable "prod3_host" {
  description = "SSH hostname for prod3 VM"
  type        = string
  default     = "prod3.home.sf.cktom.cyou"
}

variable "talos_version" {
  description = "Talos OS version"
  type        = string
  default     = "v1.7.0"
}

variable "talos_cluster_name" {
  description = "Talos cluster name"
  type        = string
  default     = "talos-cluster"
}

variable "talos_netbird_setup_key" {
  description = "Netbird setup key for Talos"
  type        = string
  sensitive   = true
  default     = ""
}

variable "talos_netbird_management_url" {
  description = "Netbird management URL for Talos"
  type        = string
  default     = ""
}
