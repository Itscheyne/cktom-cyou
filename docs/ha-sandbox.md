# Home Assistant Sandbox

Isolated clone of the production Home Assistant VM for Hermes to
experiment against without touching real automations, real network
devices, or the real Zigbee/Z-Wave USB radios.

## Topology

| | Production | Sandbox |
|---|---|---|
| Resource | `node4_homeassistant_ha` | `node3_homeassistant_sandbox` |
| Host | node4 | node3 |
| VM ID | 110 | 111 |
| Network | `vmbr0` (flat prod LAN, untagged) | `node3` SDN bridge (NAT'd, isolated) |
| IP | prod LAN DHCP/static | `10.13.0.7` (static DHCP lease) |
| MAC | `BC:24:11:E8:05:22` | `D0:99:13:5A:11:CE` |
| USB passthrough | Zigbee/Z-Wave/BT sticks | **none** |
| `on_boot` | true | false (manual start only) |

The `node3` SDN bridge is a per-node NAT zone (`10.13.0.0/24`, SNAT via
`10.0.3.13` on `vmbr0.3`). VMs on it cannot reach `vmbr0` (production
LAN), the production HA VM, or any USB-passthrough hardware, which
lives only on node4's PCI/USB bus. The sandbox's HA UI is reachable at
`http://10.13.0.7:8123` only from inside that NAT segment or via a
host that routes into it (e.g. node3 itself, or an admin jump host)
— it has no path from the WAN or the production VLAN.

## Clone procedure (IaC — primary path)

The sandbox is defined in `node3.tf` as a `proxmox_virtual_environment_vm`
resource with a `clone` block pointing at the production VM
(`node_name = "node4"`, `vm_id = 110`, `full = true`). To (re)create it:

```bash
cd ~/cktom-cyou
tofu init
tofu plan -target=proxmox_virtual_environment_vm.node3_homeassistant_sandbox
tofu apply -target=proxmox_virtual_environment_vm.node3_homeassistant_sandbox
```

Changes go through the normal PR workflow (`tofu-plan.yml` /
`tofu-apply.yml`) — do not `apply` directly against `main`.

## Reset to clean state (destroy + re-clone)

Because the clone is defined as a first-class Tofu resource, "reset" is
destroy-then-recreate. From `~/cktom-cyou`:

```bash
tofu destroy -target=proxmox_virtual_environment_vm.node3_homeassistant_sandbox
tofu apply   -target=proxmox_virtual_environment_vm.node3_homeassistant_sandbox
```

## Reset procedure (raw Proxmox fallback)

If Tofu/CI is unavailable, the same clone can be driven directly against
the Proxmox API from a host with `pvesh`/`qm` access:

```bash
# Destroy the old sandbox VM (if present)
ssh root@node3.sf.cktom.cyou "qm stop 111 --skiplock 1 2>/dev/null; qm destroy 111 --purge 1"

# Full clone of prod VM 110 (on node4) onto node3 as VM 111
ssh root@node4.sf.cktom.cyou \
  "qm clone 110 111 --name homeassistant-sandbox --full 1 --target node3 --storage rpool-zvols"

# Rewire NIC to the isolated node3 SDN bridge with the sandbox MAC,
# and confirm no usb/hostpci lines survived the clone.
ssh root@node3.sf.cktom.cyou "qm set 111 --net0 virtio=D0:99:13:5A:11:CE,bridge=node3"
ssh root@node3.sf.cktom.cyou "qm config 111 | grep -Ei '^(usb|hostpci)' && echo 'WARNING: passthrough present, remove before starting' || echo 'OK: no passthrough'"

ssh root@node3.sf.cktom.cyou "qm start 111"
```

After either path, re-run the `qm config 111 | grep -Ei '^(usb|hostpci)'`
check before starting the VM. Production USB passthrough devices are
attached by physical `host=<vendor:product>` id local to node4's bus;
Proxmox does not carry those over on clone, but always verify rather
than assume.

## First boot on the sandbox

The cloned disk boots with the production HA config/database as of
clone time (real entity history, same `configuration.yaml`, same
integrations list). To make it safe to leave running unattended:

1. Confirm `docs/ha-sandbox.md`'s network isolation above holds
   (`ip route` on the sandbox should show no route to the prod LAN).
2. In the HA UI, disable/remove any cloud, notification, or webhook
   integrations that could act on real-world state (see the
   `homeassistant-specialist` hardening task for the full checklist —
   this VM only guarantees network isolation, not integration-level
   safety).
3. Verify `qm config 111` shows no `usb*`/`hostpci*` lines.
