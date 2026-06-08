# ──────────────────────────────────────────────
# Network Configuration
#
# Both nodes use VLAN-aware Linux bridges with
# SDN "internal" zones providing NAT'd VM networks.
#
# VLAN layout (shared across both nodes):
#   VLAN 3 — Management/general (DHCP from upstream)
#   VLAN 4 — Secondary (DHCP from upstream)
#
# SDN internal networks:
#   node3: 10.13.0.0/24 → SNAT via 10.0.3.13 on vmbr0.3
#   node4: 10.14.0.0/24 → SNAT via 10.0.3.14 on vmbr0.3
#
# DNS domain: <node>.sf.cktom.cyou
# DHCP: dnsmasq, static leases only (dhcp-ignore=tag:!known)
# ──────────────────────────────────────────────

# ── node3 Network Bridges ───────────────────
#
# Physical NICs:
#   enp11s0 — RTL8111H 1GbE         → vmbr0 (main bridge)
#   enp8s0  — Intel 82599ES 10G SFP+ → vmbr1 (sniffing/mirror, MTU 9000)
#   enp7s0  — I225-V 2.5GbE         → vmbr2 (VLAN-aware, VIDs 2-4)
#
# vmbr0: VLAN-aware, STP on, VIDs 2-4093
#   vmbr0.3 — DHCP (mgmt)
#   vmbr0.4 — DHCP (secondary)
#
# vmbr1: Dedicated mirror/sniff bridge (MTU 9000, offloads disabled)
#
# vmbr2: VLAN-aware on 2.5GbE, STP on, VIDs 2-4

resource "proxmox_network_linux_bridge" "node3_vmbr0" {
  provider  = proxmox.node3
  node_name = "node3"
  name      = "vmbr0"

  ports      = ["enp11s0"]
  vlan_aware = true
  autostart  = true

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_network_linux_bridge" "node3_vmbr1" {
  provider  = proxmox.node3
  node_name = "node3"
  name      = "vmbr1"

  ports      = ["enp8s0"]
  vlan_aware = false
  mtu        = 9000
  autostart  = true

  # Sniffing/mirror bridge — STP off, aging 0, offloads disabled via post-up

  lifecycle {
    ignore_changes = all
  }
}

resource "proxmox_network_linux_bridge" "node3_vmbr2" {
  provider  = proxmox.node3
  node_name = "node3"
  name      = "vmbr2"

  ports      = ["enp7s0"]
  vlan_aware = true
  autostart  = true

  lifecycle {
    ignore_changes = all
  }
}

# ── node4 Network Bridges ───────────────────
#
# Physical NICs:
#   eno1 — onboard NIC → vmbr0 (main bridge)
#
# vmbr0: VLAN-aware, STP on, VIDs 1-4094
#   vmbr0.3 — DHCP (mgmt)
#   vmbr0.4 — DHCP (secondary)

resource "proxmox_network_linux_bridge" "node4_vmbr0" {
  provider  = proxmox.node4
  node_name = "node4"
  name      = "vmbr0"

  ports      = ["eno1"]
  vlan_aware = true
  autostart  = true

  lifecycle {
    ignore_changes = all
  }
}

# ── SDN Zones ────────────────────────────────
#
# "internal" zone — Simple SDN zone providing per-node NAT'd subnets
# Each node gets its own bridge (named after the node) with:
#   - A /24 subnet for VMs
#   - SNAT to the node's vmbr0.3 address
#   - dnsmasq DHCP (static leases only)
#
# "localnetwork" zone — default local zone (status: ok on both nodes)

# Note: The bpg/proxmox provider has limited SDN support.
# These resources document the configuration; you may need to
# manage SDN zones via the Proxmox API or datacenter.cfg directly.

# ── SDN Network Documentation ───────────────
#
# node3 SDN bridge "node3":
#   Address:  10.13.0.1/24
#   SNAT:     10.13.0.0/24 → 10.0.3.13 via vmbr0.3
#   DHCP:     dnsmasq, static only, domain node3.sf.cktom.cyou
#   Features: ip-forward, conntrack zone 1
#
# node4 SDN bridge "node4":
#   Address:  10.14.0.1/24
#   SNAT:     10.14.0.0/24 → 10.0.3.14 via vmbr0.3
#   DHCP:     dnsmasq, static only, rapid-commit, reverse DNS
#   Features: ip-forward, conntrack zone 1
#
# ── DHCP Static Leases ──────────────────────
#
# node3 (10.13.0.0/24):
#   D0:99:13:08:00:01 → 10.13.0.2  (prod3/800 net0 on node3 SDN)
#   D0:99:13:60:65:80 → 10.13.0.4  (clearndr/489 net0 on node3 SDN)
#   D0:99:13:49:50:5A → 10.13.0.5  (nast/400 net1 on node3 SDN)
#   D0:99:13:52:E5:BA → 10.13.0.6  (homeassistant-test/10110 net0 on node3 SDN)
#
# node4 (10.14.0.0/24):
#   D0:99:14:79:63:04 → 10.14.0.2  (prod4/443 net2 on node4 SDN)
