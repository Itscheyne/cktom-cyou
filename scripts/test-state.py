#!/usr/bin/env python3
"""
test-state.py — Validate OpenTofu state against known resource inventory.

Reads `tofu show -json` output and asserts that all expected resources
are present with correct node assignments and VM IDs. Fails fast on
any missing resource or ID mismatch.

Usage:
    tofu show -json | python3 scripts/test-state.py
    # or from a saved plan:
    tofu show -json tfplan.binary | python3 scripts/test-state.py

Exit codes:
    0 — all assertions pass
    1 — one or more assertions failed
"""

import json
import sys


# ─── Expected resource inventory ──────────────────────────────────────────────
# Update this when adding/removing/renaming resources in IaC.
# Sourced from modules/node3/vms.tf and modules/node4/vms.tf.
# null_resource entries are excluded (no node_name/vm_id to validate).

EXPECTED = {
    # ── node3 VMs ──
    "module.node3.proxmox_virtual_environment_vm.node3_nast":                {"vm_id": 400,   "node": "node3"},
    "module.node3.proxmox_virtual_environment_vm.node3_utm":                 {"vm_id": 490,   "node": "node3"},
    "module.node3.proxmox_virtual_environment_vm.node3_so":                  {"vm_id": 500,   "node": "node3"},
    "module.node3.proxmox_virtual_environment_vm.node3_so_oc":               {"vm_id": 501,   "node": "node3"},
    "module.node3.proxmox_virtual_environment_vm.node3_prod3":               {"vm_id": 800,   "node": "node3"},
    "module.node3.proxmox_virtual_environment_vm.node3_homeassistant_test":  {"vm_id": 10110, "node": "node3"},
    "module.node3.proxmox_virtual_environment_vm.node3_homeassistant":       {"vm_id": 110,   "node": "node3"},
    "module.node3.proxmox_virtual_environment_vm.node3_alma_template":       {"vm_id": 700,   "node": "node3"},
    "module.node3.proxmox_virtual_environment_vm.node3_dev":                 {"vm_id": 299,   "node": "node3"},
    "module.node3.proxmox_virtual_environment_vm.node3_fipa":                {"vm_id": 389,   "node": "node3"},
    "module.node3.proxmox_virtual_environment_vm.node3_prod3_1":             {"vm_id": 801,   "node": "node3"},
    "module.node3.proxmox_virtual_environment_vm.node3_dev3":                {"vm_id": 901,   "node": "node3"},
    "module.node3.proxmox_virtual_environment_vm.node3_prod3_0":             {"vm_id": 8001,  "node": "node3"},
    # ── node3 containers ──
    "module.node3.proxmox_virtual_environment_container.node3_storage":      {"vm_id": 777,   "node": "node3"},
    "module.node3.proxmox_virtual_environment_container.node3_nast":         {"vm_id": 445,   "node": "node3"},
    "module.node3.proxmox_virtual_environment_container.node3_dir":          {"vm_id": 10389, "node": "node3"},
    "module.node3.proxmox_virtual_environment_container.node3_ollama":       {"vm_id": 114,   "node": "node3"},
    # ── node4 VMs ──
    "module.node4.proxmox_virtual_environment_vm.node4_pdm":                 {"vm_id": 1001,  "node": "node4"},
    "module.node4.proxmox_virtual_environment_vm.node4_homeassistant_ha":    {"vm_id": 110,   "node": "node4"},
    "module.node4.proxmox_virtual_environment_vm.node4_vm_homeassistant":    {"vm_id": 103,   "node": "node4"},
    "module.node4.proxmox_virtual_environment_vm.node4_openneb":             {"vm_id": 1040,  "node": "node4"},
    "module.node4.proxmox_virtual_environment_vm.node4_incus":               {"vm_id": 2000,  "node": "node4"},
    "module.node4.proxmox_virtual_environment_vm.node4_cp0":                 {"vm_id": 900,   "node": "node4"},
    "module.node4.proxmox_virtual_environment_vm.node4_w1":                  {"vm_id": 901,   "node": "node4"},
    "module.node4.proxmox_virtual_environment_vm.node4_dev":                 {"vm_id": 999,   "node": "node4"},
    "module.node4.proxmox_virtual_environment_vm.node4_almacloud_template":  {"vm_id": 202,   "node": "node4"},
    "module.node4.proxmox_virtual_environment_vm.node4_flustercuck_template":{"vm_id": 800,   "node": "node4"},
    "module.node4.proxmox_virtual_environment_vm.node4_talos_template":      {"vm_id": 899,   "node": "node4"},
    "module.node4.proxmox_virtual_environment_vm.node4_fipa":                {"vm_id": 150,   "node": "node4"},
}

# ── Networking bridges that must exist ────────────────────────────────────────
EXPECTED_BRIDGES = {
    "module.node3.proxmox_network_linux_bridge.node3_vmbr0": "node3",
    "module.node3.proxmox_network_linux_bridge.node3_vmbr1": "node3",
    "module.node3.proxmox_network_linux_bridge.node3_vmbr2": "node3",
    "module.node4.proxmox_network_linux_bridge.node4_vmbr0": "node4",
}


def load_state_from_str(text):
    """Parse `tofu show -json` output string. Handles plan and state formats."""
    data = json.loads(text)
    # Both plan and state share: {"values": {"root_module": ...}}
    root = data.get("values", {}).get("root_module", {})
    return root


def collect_resources(module, prefix=""):
    """Recursively collect all resources from module tree."""
    resources = {}
    for res in module.get("resources", []):
        addr = res.get("address", "")
        full_addr = f"{prefix}.{addr}" if prefix else addr
        resources[full_addr] = res
    for child in module.get("child_modules", []):
        child_addr = child.get("address", "")
        resources.update(collect_resources(child, child_addr))
    return resources


def run_assertions(resources):
    failures = []
    passed = 0

    # ── Check VMs and containers ──────────────────────────────────────────────
    for addr, expected in EXPECTED.items():
        if addr not in resources:
            failures.append(f"MISSING        {addr}")
            continue

        res = resources[addr]
        vals = res.get("values", {})

        got_node = vals.get("node_name", "")
        if got_node != expected["node"]:
            failures.append(f"NODE_MISMATCH  {addr}: want={expected['node']} got={got_node}")
            continue

        # vm_id used for both VMs and containers in bpg/proxmox provider
        got_id = vals.get("vm_id")
        if got_id != expected["vm_id"]:
            failures.append(f"ID_MISMATCH    {addr}: want={expected['vm_id']} got={got_id}")
            continue

        passed += 1

    # ── Check networking bridges ──────────────────────────────────────────────
    for addr, expected_node in EXPECTED_BRIDGES.items():
        if addr not in resources:
            failures.append(f"MISSING_BRIDGE {addr}")
            continue
        vals = resources[addr].get("values", {})
        got_node = vals.get("node_name", "")
        if got_node != expected_node:
            failures.append(f"BRIDGE_NODE_MISMATCH  {addr}: want={expected_node} got={got_node}")
            continue
        passed += 1

    return passed, failures


def main():
    print("=== IaC State Validation ===")

    try:
        raw = sys.stdin.read()
    except Exception as e:
        print(f"ERROR: Failed to read stdin: {e}")
        sys.exit(1)

    if not raw.strip():
        print("ERROR: No input. Pipe `tofu show -json` output into this script.")
        print("  tofu show -json | python3 scripts/test-state.py")
        sys.exit(1)

    try:
        root = load_state_from_str(raw)
    except json.JSONDecodeError as e:
        print(f"ERROR: Failed to parse JSON input: {e}")
        sys.exit(1)

    resources = collect_resources(root)
    print(f"Resources found in state: {len(resources)}")

    passed, failures = run_assertions(resources)

    total = passed + len(failures)
    print(f"Assertions passed: {passed}/{total}")

    if failures:
        print("\nFAILURES:")
        for f in failures:
            print(f"  {f}")
        print(f"\nFAIL: {len(failures)} assertion(s) failed.")
        sys.exit(1)
    else:
        print("\nPASS: All assertions passed.")
        sys.exit(0)


if __name__ == "__main__":
    main()
