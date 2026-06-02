terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.78.0"
    }
  }
}

provider "proxmox" {
  alias     = "node1"
  endpoint  = var.node1_endpoint
  api_token = var.node1_api_token
  username  = var.node1_api_token == null ? var.node1_username : null
  password  = var.node1_api_token == null ? var.node1_password : null
  insecure  = var.proxmox_insecure

  ssh {
    agent = true
  }
}

provider "proxmox" {
  alias     = "node3"
  endpoint  = var.node3_endpoint
  api_token = var.node3_api_token
  username  = var.node3_api_token == null ? var.node3_username : null
  password  = var.node3_api_token == null ? var.node3_password : null
  insecure  = var.proxmox_insecure

  ssh {
    agent = true
  }
}

provider "proxmox" {
  alias     = "node4"
  endpoint  = var.node4_endpoint
  api_token = var.node4_api_token
  username  = var.node4_api_token == null ? var.node4_username : null
  password  = var.node4_api_token == null ? var.node4_password : null
  insecure  = var.proxmox_insecure

  ssh {
    agent = true
  }
}
