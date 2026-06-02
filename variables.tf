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
  default     = null
}

variable "node1_api_token" {
  description = "Proxmox VE API token for node1 (e.g. agents@pve!dev=<secret>). Takes precedence over password when set."
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
}

variable "node3_password" {
  description = "Proxmox VE API password for node3"
  type        = string
  sensitive   = true
  default     = null
}

variable "node3_api_token" {
  description = "Proxmox VE API token for node3 (e.g. agents@pve!dev=<secret>). Takes precedence over password when set."
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
}

variable "node4_password" {
  description = "Proxmox VE API password for node4"
  type        = string
  sensitive   = true
  default     = null
}

variable "node4_api_token" {
  description = "Proxmox VE API token for node4 (e.g. agents@pve!dev=<secret>). Takes precedence over password when set."
  type        = string
  sensitive   = true
  default     = null
}
