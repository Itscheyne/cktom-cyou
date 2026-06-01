# ──────────────────────────────────────────────
# Access Control for AI
# ──────────────────────────────────────────────

# -- node1 --

resource "proxmox_virtual_environment_user" "node1_proxmin" {
  provider = proxmox.node1
  user_id  = "proxmin@pve"
  comment  = "Break-glass admin account for AI troubleshooting"

  acl {
    path      = "/"
    propagate = true
    role_id   = "Administrator"
  }
}

# -- node3 --

resource "proxmox_virtual_environment_user" "node3_proxmin" {
  provider = proxmox.node3
  user_id  = "proxmin@pve"
  comment  = "Break-glass admin account for AI troubleshooting"

  acl {
    path      = "/"
    propagate = true
    role_id   = "Administrator"
  }
}

# -- node4 --

resource "proxmox_virtual_environment_user" "node4_proxmin" {
  provider = proxmox.node4
  user_id  = "proxmin@pve"
  comment  = "Break-glass admin account for AI troubleshooting"

  acl {
    path      = "/"
    propagate = true
    role_id   = "Administrator"
  }
}

# ──────────────────────────────────────────────
# GHA CI/CD user (ghprod@pve)
# plan token → AIAgent role (read-only)
# apply token → Administrator role (write)
# ──────────────────────────────────────────────

# -- node1 --

resource "proxmox_virtual_environment_user" "node1_ghprod" {
  provider = proxmox.node1
  user_id  = "ghprod@pve"
  comment  = "GitHub Actions CI/CD user for tofu plan and apply"

  acl {
    path      = "/"
    propagate = true
    role_id   = "Administrator"
  }
}

# -- node3 --

resource "proxmox_virtual_environment_user" "node3_ghprod" {
  provider = proxmox.node3
  user_id  = "ghprod@pve"
  comment  = "GitHub Actions CI/CD user for tofu plan and apply"

  acl {
    path      = "/"
    propagate = true
    role_id   = "Administrator"
  }
}

# -- node4 --

resource "proxmox_virtual_environment_user" "node4_ghprod" {
  provider = proxmox.node4
  user_id  = "ghprod@pve"
  comment  = "GitHub Actions CI/CD user for tofu plan and apply"

  acl {
    path      = "/"
    propagate = true
    role_id   = "Administrator"
  }
}

# ──────────────────────────────────────────────
# Access Control for AI Agents (read-only GitOps)
# ──────────────────────────────────────────────

# -- node1 --

resource "proxmox_virtual_environment_role" "node1_ai_agent" {
  provider = proxmox.node1
  role_id  = "AIAgent"

  privileges = [
    "VM.Audit",
    "VM.Config.Disk",
    "VM.GuestAgent.Audit",
    "Datastore.Audit",
    "Sys.Audit",
    "Pool.Audit",
    "SDN.Audit",
    "SDN.Allocate",
  ]
}

resource "proxmox_virtual_environment_user" "node1_agents" {
  provider = proxmox.node1
  user_id  = "agents@pve"
  comment  = "Read-only user for AI agent GitOps tofu plan context"

  acl {
    path      = "/"
    propagate = true
    role_id   = proxmox_virtual_environment_role.node1_ai_agent.role_id
  }
}

# -- node3 --

resource "proxmox_virtual_environment_role" "node3_ai_agent" {
  provider = proxmox.node3
  role_id  = "AIAgent"

  privileges = [
    "VM.Audit",
    "VM.Config.Disk",
    "VM.GuestAgent.Audit",
    "Datastore.Audit",
    "Sys.Audit",
    "Pool.Audit",
    "SDN.Audit",
    "SDN.Allocate",
  ]
}

resource "proxmox_virtual_environment_user" "node3_agents" {
  provider = proxmox.node3
  user_id  = "agents@pve"
  comment  = "Read-only user for AI agent GitOps tofu plan context"

  acl {
    path      = "/"
    propagate = true
    role_id   = proxmox_virtual_environment_role.node3_ai_agent.role_id
  }
}

# -- node4 --

resource "proxmox_virtual_environment_role" "node4_ai_agent" {
  provider = proxmox.node4
  role_id  = "AIAgent"

  privileges = [
    "VM.Audit",
    "VM.Config.Disk",
    "VM.GuestAgent.Audit",
    "Datastore.Audit",
    "Sys.Audit",
    "Pool.Audit",
    "SDN.Audit",
    "SDN.Allocate",
  ]
}

resource "proxmox_virtual_environment_user" "node4_agents" {
  provider = proxmox.node4
  user_id  = "agents@pve"
  comment  = "Read-only user for AI agent GitOps tofu plan context"

  acl {
    path      = "/"
    propagate = true
    role_id   = proxmox_virtual_environment_role.node4_ai_agent.role_id
  }
}

# ── Import existing users ────────────────────

import {
  provider = proxmox.node1
  to       = proxmox_virtual_environment_user.node1_proxmin
  id       = "proxmin@pve"
}

import {
  provider = proxmox.node3
  to       = proxmox_virtual_environment_user.node3_proxmin
  id       = "proxmin@pve"
}

import {
  provider = proxmox.node4
  to       = proxmox_virtual_environment_user.node4_proxmin
  id       = "proxmin@pve"
}
