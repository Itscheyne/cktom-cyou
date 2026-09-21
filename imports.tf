# ──────────────────────────────────────────────
# Import blocks for existing infrastructure discovered during
# drift reconciliation (see tofu-drift workflow run 35504768322).
#
# Run `tofu plan` to preview, then `tofu apply` to import existing
# resources into state. Remove these blocks after successful import.
# ──────────────────────────────────────────────

# ── node3 resource pools (pre-existing live pools, never imported) ──

import {
  to = module.node3.proxmox_virtual_environment_pool.dev
  id = "dev"
}

import {
  to = module.node3.proxmox_virtual_environment_pool.prod
  id = "prod"
}

import {
  to = module.node3.proxmox_virtual_environment_pool.protected
  id = "protected"
}

# ── node3 containers (pre-existing live LXCs, never imported) ──

import {
  to = module.node3.proxmox_virtual_environment_container.node3_llama0
  id = "node3/100"
}

import {
  to = module.node3.proxmox_virtual_environment_container.node3_llama
  id = "node3/1001"
}

# NOTE: config resource name is node3_ollama_new but the live container it
# matches by vm_id (1002) is actually named "ollama", not "ollama_new".
# Importing by vm_id/address only — does not rename the live container.
import {
  to = module.node3.proxmox_virtual_environment_container.node3_ollama_new
  id = "node3/1002"
}

# node3_ollama (vm_id 114, config resource distinct from node3_ollama_new
# above) has NO matching live container — vmid 114 does not exist on node3.
# Left as a genuine "create" in the plan; not imported.

# ── node3 ACLs (new proxmox_acl resources from the user/acl split; the
# underlying proxmox_virtual_environment_user resources are already in
# state and untouched — only the ACL grant itself needs importing) ──

import {
  to = module.node3.proxmox_acl.node3_proxmin
  id = "/?proxmin@pve?Administrator"
}

# CAUTION: live role for ghprod@pve is PVEAdmin, but access.tf declares
# Administrator. Importing at the LIVE role turns this from a silent
# "+ create" (implicit permission widen) into a reviewable "~ update"
# in the next plan. Do NOT change access.tf to match live — the intended
# role is a human decision; see PR description.
import {
  to = module.node3.proxmox_acl.node3_ghprod
  id = "/?ghprod@pve?PVEAdmin"
}

import {
  to = module.node3.proxmox_acl.node3_agents
  id = "/?agents@pve?AIAgent"
}

# ── node4 ACLs (same user/acl split as node3) ──

import {
  to = module.node4.proxmox_acl.node4_proxmin
  id = "/?proxmin@pve?Administrator"
}

# Same live-role mismatch as node3_ghprod above (live=PVEAdmin, config
# wants Administrator) — imported at live role so the widen surfaces as
# a reviewable update, not a silent create.
import {
  to = module.node4.proxmox_acl.node4_ghprod
  id = "/?ghprod@pve?PVEAdmin"
}

import {
  to = module.node4.proxmox_acl.node4_agents
  id = "/?agents@pve?AIAgent"
}

# node4_hermes ACL: no matching live grant exists (hermes@pve has no ACL
# entry on node4 yet) — left as a genuine "create", not imported.

# ── node4 users ──

import {
  to = module.node4.proxmox_virtual_environment_user.node4_hermes
  id = "hermes@pve"
}
