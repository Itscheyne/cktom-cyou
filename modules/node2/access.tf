# node2 access control — moved from root access.tf.
# proxmin: break-glass admin. ghprod: GHA CI/CD. agents: read-only GitOps.

resource "proxmox_virtual_environment_user" "node2_proxmin" {
  provider = proxmox
  user_id  = "proxmin@pve"
  comment  = "Break-glass admin account for AI troubleshooting"

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_acl" "node2_proxmin" {
  provider = proxmox
  user_id  = "proxmin@pve"
  path      = "/"
  propagate = true
  role_id   = "Administrator"
  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_user" "node2_ghprod" {
  provider = proxmox
  user_id  = "ghprod@pve"
  comment  = "GitHub Actions CI/CD user for tofu plan and apply"

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_acl" "node2_ghprod" {
  provider = proxmox
  user_id  = "ghprod@pve"
  path      = "/"
  propagate = true
  role_id   = "Administrator"
  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_role" "node2_ai_agent" {
  provider = proxmox
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
  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_user" "node2_agents" {
  provider = proxmox
  user_id  = "agents@pve"
  comment  = "Read-only user for AI agent GitOps tofu plan context"

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_acl" "node2_agents" {
  provider = proxmox
  user_id  = "agents@pve"
  path      = "/"
  propagate = true
  role_id   = proxmox_virtual_environment_role.node2_ai_agent.role_id
  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_virtual_environment_user" "node2_hermes" {
  provider = proxmox
  user_id  = "hermes@pve"
  comment  = "Provisioned for AI agent audit access dynamically"

}

resource "proxmox_acl" "node2_hermes" {
  provider = proxmox
  user_id  = "hermes@pve"
  path      = "/"
  propagate = true
  role_id   = proxmox_virtual_environment_role.node2_ai_agent.role_id
  lifecycle {
    ignore_changes = all
  }
}
