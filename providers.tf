terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.78.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.11.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.1.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.1.0"
    }
  }
}

provider "proxmox" {
  alias    = "node1"
  endpoint = var.node1_endpoint
  username = var.node1_username
  password = var.node1_password
  insecure = var.proxmox_insecure

  ssh {
    agent = true
  }
}

provider "proxmox" {
  alias    = "node3"
  endpoint = var.node3_endpoint
  username = var.node3_username
  password = var.node3_password
  insecure = var.proxmox_insecure

  ssh {
    agent = true
  }
}

provider "proxmox" {
  alias    = "node4"
  endpoint = var.node4_endpoint
  username = var.node4_username
  password = var.node4_password
  insecure = var.proxmox_insecure

  ssh {
    agent = true
  }
}
