# modules/node3 — provider receiver.
# Proxmox provider passed in from root (configured for node3 host).

terraform {
  required_providers {
    proxmox = {
      source                = "bpg/proxmox"
      version               = ">= 0.78.0"
      configuration_aliases = [proxmox]
    }
  }
}
