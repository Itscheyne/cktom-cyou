# GEMINI context: cktom-cyou

Infrastructure as Code (IaC) for the `cktom-cyou` Proxmox Virtual Environment (PVE) cluster, managed via Terraform/OpenTofu.

## Project Overview

- **Purpose:** Manages the baseline configuration, networking, and virtual machines for a multi-node Proxmox cluster.
- **Main Technologies:**
    - **Terraform / OpenTofu:** Infrastructure orchestration.
    - **Proxmox Provider (`bpg/proxmox`):** Primary provider for PVE resource management.
    - **Proxmox VE:** Virtualization platform.
    - **ZFS:** Underlying storage technology used for pools (`rpool`, `datapool`, `imagepool`).
    - **Linux Bridges & SDN:** Networking via VLAN-aware bridges and Proxmox SDN zones.

## Architecture

The infrastructure is split across two main physical nodes:

### node3 (High Capacity)
- **Hardware:** 16 CPU cores, ~62 GB RAM.
- **Storage:** `rpool`, `datapool0`, `datapool1`.
- **Key Workloads:**
    - `nast`: Network Attached Storage.
    - `so` / `so-oc`: Security Onion (IDS/NSM).
    - `prod3`: Production node.
    - `homeassistant`: Smart home controller (with USB passthrough).
- **Networking:** Includes a dedicated 10G SFP+ bridge (`vmbr1`) for sniffing/mirroring traffic.

### node4 (Standard Capacity)
- **Hardware:** 8 CPU cores, ~14.6 GB RAM.
- **Storage:** `rpool`, `datapool0`, `imagepool0`.
- **Key Workloads:**
    - `pdm`: Proxmox Datacenter Manager.
    - `prod4`: Production node.
    - `homeassistant-HA`: High-availability instance.
    - Various templates (AlmaCloud, Talos).

## Building and Running

The project is compatible with OpenTofu (or Terraform).

- **Initialize:** `tofu init`
- **Plan:** `tofu plan`
- **Apply:** `tofu apply`

**Note on Imports:** The project uses `imports.tf` to bring existing manually-created resources into state. After a successful `apply`, these blocks should typically be removed.

## Development Conventions

- **Resource Naming:** Virtual machines are generally named using the pattern `node<X>_<vm_name>` in Terraform.
- **Lifecycle Management:** Many resources use `lifecycle { ignore_changes = all }`. This indicates that Terraform is used to define the *baseline* configuration, but subsequent changes (e.g., via the Proxmox UI) are not strictly enforced or reverted by the IaC.
- **Networking Layout:**
    - **VLAN 3:** Management/General (DHCP from upstream).
    - **VLAN 4:** Secondary (DHCP from upstream).
    - **SDN Zones:** `node3` and `node4` zones provide internal NAT'd networks (10.13.0.0/24 and 10.14.0.0/24).
- **Workflow (`.haft`):**
    - The project follows a structured workflow defined in `.haft/workflow.md`.
    - Biases toward small, reversible changes.
    - Requires explicit decisions for core/domain edits.
    - Verification via concrete runtime evidence is required.

## Key Files

- `providers.tf`: Provider configuration for Proxmox.
- `variables.tf`: Input variables (endpoint, credentials).
- `networking.tf`: Detailed network bridge and SDN configuration.
- `node3.tf` / `node4.tf`: VM and Container definitions for respective nodes.
- `pools.tf`: Resource pool definitions.
- `imports.tf`: Import blocks for existing infrastructure.
