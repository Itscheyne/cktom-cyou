# ──────────────────────────────────────────────
# Import blocks for existing infrastructure
#
# Run `tofu plan` to preview, then `tofu apply`
# to import existing resources into state.
# Remove these blocks after successful import.
# ──────────────────────────────────────────────

# ── Network Bridges ──────────────────────────

import {
  provider = proxmox.node3
  to       = proxmox_network_linux_bridge.node3_vmbr0
  id       = "node3:vmbr0"
}

import {
  provider = proxmox.node3
  to       = proxmox_network_linux_bridge.node3_vmbr1
  id       = "node3:vmbr1"
}

import {
  provider = proxmox.node3
  to       = proxmox_network_linux_bridge.node3_vmbr2
  id       = "node3:vmbr2"
}

import {
  provider = proxmox.node4
  to       = proxmox_network_linux_bridge.node4_vmbr0
  id       = "node4:vmbr0"
}

# ── Resource Pools ───────────────────────────

import {
  provider = proxmox.node3
  to       = proxmox_virtual_environment_pool.security_onion
  id       = "SecurityOnion"
}

import {
  provider = proxmox.node3
  to       = proxmox_virtual_environment_pool.mosse
  id       = "mosse"
}

import {
  provider = proxmox.node3
  to       = proxmox_virtual_environment_pool.talos
  id       = "talos"
}

# ── node4 VMs ────────────────────────────────

import {
  provider = proxmox.node4
  to       = proxmox_virtual_environment_vm.node4_pdm
  id       = "qemu/1001"
}

import {
  provider = proxmox.node4
  to       = proxmox_virtual_environment_vm.node4_homeassistant_ha
  id       = "qemu/110"
}

import {
  provider = proxmox.node4
  to       = proxmox_virtual_environment_vm.node4_vm_homeassistant
  id       = "qemu/103"
}

import {
  provider = proxmox.node4
  to       = proxmox_virtual_environment_vm.node4_openneb
  id       = "qemu/1040"
}

import {
  provider = proxmox.node4
  to       = proxmox_virtual_environment_vm.node4_incus
  id       = "qemu/2000"
}

import {
  provider = proxmox.node4
  to       = proxmox_virtual_environment_vm.node4_cp0
  id       = "qemu/900"
}

import {
  provider = proxmox.node4
  to       = proxmox_virtual_environment_vm.node4_w1
  id       = "qemu/901"
}

import {
  provider = proxmox.node4
  to       = proxmox_virtual_environment_vm.node4_dev
  id       = "qemu/999"
}

import {
  provider = proxmox.node4
  to       = proxmox_virtual_environment_vm.node4_almacloud_template
  id       = "qemu/202"
}

import {
  provider = proxmox.node4
  to       = proxmox_virtual_environment_vm.node4_flustercuck_template
  id       = "qemu/800"
}

import {
  provider = proxmox.node4
  to       = proxmox_virtual_environment_vm.node4_talos_template
  id       = "qemu/899"
}

import {
  provider = proxmox.node4
  to       = proxmox_virtual_environment_vm.node4_fipa
  id       = "qemu/150"
}

# ── node3 VMs ────────────────────────────────

import {
  provider = proxmox.node3
  to       = proxmox_virtual_environment_vm.node3_nast
  id       = "qemu/400"
}

import {
  provider = proxmox.node3
  to       = proxmox_virtual_environment_vm.node3_utm
  id       = "qemu/490"
}

import {
  provider = proxmox.node3
  to       = proxmox_virtual_environment_vm.node3_so
  id       = "qemu/500"
}

import {
  provider = proxmox.node3
  to       = proxmox_virtual_environment_vm.node3_prod3
  id       = "qemu/800"
}

import {
  provider = proxmox.node3
  to       = proxmox_virtual_environment_vm.node3_homeassistant
  id       = "qemu/110"
}

import {
  provider = proxmox.node3
  to       = proxmox_virtual_environment_vm.node3_so_oc
  id       = "qemu/501"
}

import {
  provider = proxmox.node3
  to       = proxmox_virtual_environment_vm.node3_homeassistant_test
  id       = "qemu/10110"
}

import {
  provider = proxmox.node3
  to       = proxmox_virtual_environment_vm.node3_alma_template
  id       = "qemu/700"
}

# ── node3 additional VMs ─────────────────────

import {
  provider = proxmox.node3
  to       = proxmox_virtual_environment_vm.node3_dev
  id       = "qemu/299"
}

import {
  provider = proxmox.node3
  to       = proxmox_virtual_environment_vm.node3_fipa
  id       = "qemu/389"
}

import {
  provider = proxmox.node3
  to       = proxmox_virtual_environment_vm.node3_prod3_1
  id       = "qemu/801"
}

import {
  provider = proxmox.node3
  to       = proxmox_virtual_environment_vm.node3_dev3
  id       = "qemu/901"
}

import {
  provider = proxmox.node3
  to       = proxmox_virtual_environment_vm.node3_prod3_0
  id       = "qemu/8001"
}

# ── node3 LXC ────────────────────────────────

import {
  provider = proxmox.node3
  to       = proxmox_virtual_environment_container.node3_storage
  id       = "node3/777"
}

import {
  provider = proxmox.node3
  to       = proxmox_virtual_environment_container.node3_nast
  id       = "node3/445"
}

import {
  provider = proxmox.node3
  to       = proxmox_virtual_environment_container.node3_dir
  id       = "node3/10389"
}

# ── node1 VMs ────────────────────────────────

import {
  provider = proxmox.node1
  to       = proxmox_virtual_environment_vm.node1_llama
  id       = "qemu/100"
}

import {
  provider = proxmox.node1
  to       = proxmox_virtual_environment_vm.node1_dev
  id       = "qemu/299"
}

import {
  provider = proxmox.node1
  to       = proxmox_virtual_environment_vm.node1_dev_node1
  id       = "qemu/1000"
}

import {
  provider = proxmox.node1
  to       = proxmox_virtual_environment_vm.node1_prod1
  id       = "qemu/1001"
}

import {
  provider = proxmox.node1
  to       = proxmox_virtual_environment_vm.node1_sockpot
  id       = "qemu/1071"
}

import {
  provider = proxmox.node1
  to       = proxmox_virtual_environment_vm.node1_dockbox
  id       = "qemu/2000"
}

import {
  provider = proxmox.node1
  to       = proxmox_virtual_environment_vm.node1_vllm
  id       = "qemu/2001"
}

import {
  provider = proxmox.node1
  to       = proxmox_virtual_environment_vm.node1_template_fedora_iot
  id       = "qemu/9999"
}

import {
  provider = proxmox.node1
  to       = proxmox_virtual_environment_vm.node1_flustercuck0
  id       = "qemu/10000"
}

import {
  provider = proxmox.node1
  to       = proxmox_virtual_environment_vm.node1_flustercuck1
  id       = "qemu/10001"
}

# ── node1 LXC ────────────────────────────────

import {
  provider = proxmox.node1
  to       = proxmox_virtual_environment_container.node1_stash0
  id       = "node1/103"
}

import {
  provider = proxmox.node1
  to       = proxmox_virtual_environment_container.node1_stash
  id       = "node1/111"
}
