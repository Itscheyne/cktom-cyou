# OpenTofu 1.7+ removed blocks to cleanly drop orphaned SDN resources from state
# without destroying them in the live cluster (since they contain subnets).

removed {
  from = proxmox_sdn_zone_simple.internal
  lifecycle {
    destroy = false
  }
}

removed {
  from = proxmox_sdn_vnet.node1
  lifecycle {
    destroy = false
  }
}

removed {
  from = proxmox_virtual_environment_sdn_zone_simple.internal
  lifecycle {
    destroy = false
  }
}

removed {
  from = proxmox_virtual_environment_sdn_vnet.node1
  lifecycle {
    destroy = false
  }
}
