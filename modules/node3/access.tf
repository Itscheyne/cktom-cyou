# node3 access control — moved from root access.tf.
# proxmin: break-glass admin. ghprod: GHA CI/CD. agents: read-only GitOps.

resource "proxmox_virtual_environment_user" "node3_proxmin" {
  provider = proxmox
  user_id  = "proxmin@pve"
  comment  = "Break-glass admin account for AI troubleshooting"

  acl {
    path      = "/"
    propagate = true
    role_id   = "Administrator"
  }
}

resource "proxmox_virtual_environment_user" "node3_ghprod" {
  provider = proxmox
  user_id  = "ghprod@pve"
  comment  = "GitHub Actions CI/CD user for tofu plan and apply"

  acl {
    path      = "/"
    propagate = true
    role_id   = "Administrator"
  }
}

resource "proxmox_virtual_environment_role" "node3_ai_agent" {
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
}

resource "proxmox_virtual_environment_user" "node3_agents" {
  provider = proxmox
  user_id  = "agents@pve"
  comment  = "Read-only user for AI agent GitOps tofu plan context"

  acl {
    path      = "/"
    propagate = true
    role_id   = proxmox_virtual_environment_role.node3_ai_agent.role_id
  }
}
