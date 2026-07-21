# modules/node1 — provider receivers.
# Proxmox provider passed in from root (configured for node1 host).
# talos inherited as default (unaliased) from root.

terraform {
  required_providers {
    proxmox = {
      source                = "bpg/proxmox"
      version               = ">= 0.78.0"
      configuration_aliases = [proxmox]
    }
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.11.0"
    }
  }
}
