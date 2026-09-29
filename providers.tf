terraform {
  required_version = ">=1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">=0.78.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = ">=0.7.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">=3.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=3.0.0"
    }
  }

  backend "s3" {
    bucket                      = "cktom-cyou-iac"
    key                         = "terraform.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}

provider "proxmox" {
  alias = "node1"
  # Fallback to node3 endpoint and token if node1 token is invalid/offline
  endpoint  = try(length(regexall("^[A-Za-z0-9_]+@[A-Za-z0-9_]+![A-Za-z0-9_]+=[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.node1_api_token)) > 0, false) ? var.node1_endpoint : var.node3_endpoint
  api_token = try(length(regexall("^[A-Za-z0-9_]+@[A-Za-z0-9_]+![A-Za-z0-9_]+=[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.node1_api_token)) > 0, false) ? var.node1_api_token : var.node3_api_token
  insecure  = var.proxmox_insecure

  ssh {
    agent = true
  }
}

provider "proxmox" {
  alias     = "node3"
  endpoint  = var.node3_endpoint
  api_token = var.node3_api_token != "" ? var.node3_api_token : null
  username  = var.node3_api_token != null && var.node3_api_token != "" ? null : var.node3_username
  password  = var.node3_api_token != null && var.node3_api_token != "" ? null : var.node3_password
  insecure  = var.proxmox_insecure

  ssh {
    agent = true
  }
}

provider "proxmox" {
  alias     = "node4"
  endpoint  = var.node4_endpoint
  api_token = var.node4_api_token != "" ? var.node4_api_token : null
  username  = var.node4_api_token != null && var.node4_api_token != "" ? null : var.node4_username
  password  = var.node4_api_token != null && var.node4_api_token != "" ? null : var.node4_password
  insecure  = var.proxmox_insecure

  ssh {
    agent = true
  }
}
