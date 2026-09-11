# Proxmox IaC Runbook

This runbook outlines the OpenTofu infrastructure-as-code (IaC) configuration, testing flow, and deployment process for the `cktom-cyou` Proxmox VE cluster. 

## 1. IaC Architecture & Configuration

The infrastructure is defined using `bpg/proxmox` provider (v0.78.0+). 
- **Nodes**: Managed resources deploy primarily to `node3` (16-core, 62GB RAM) and `node4` (8-core, 15GB RAM).
- **Core Files**:
  - `node3.tf` / `node4.tf`: Host-specific definitions (VMs, LXC containers).
  - `networking.tf`: SDN zones, bridges (e.g., `vmbr0`), and VLAN tagging (VLAN 3/4).
  - `pools.tf`: Proxmox resource pools.
  - `secrets/`: CI tokens and NetBird keys are injected contextually. None are committed in plaintext.

### Key Operations Principles
- **Ignore Local Changes**: Resources use `lifecycle { ignore_changes = all }`. Tofu defines the baseline; Proxmox UI modifications happen at runtime and should not be wiped out automatically during standard `apply`.
- **Naming Conventions**: Use `node<X>_<vm_name>` to remain consistent.

## 2. CI & Testing Flow

Pull Requests to the `main` branch trigger continuous integration workflows:

1. **Lint Phase**: `tofu fmt` and `tofu validate` ensure formatting and syntactical correctness.
2. **State Validation**: Uses `scripts/test-state.py` to parse `tofu show -json` and ensure all expected resources (e.g., specific VM IDs and node assignments) are present.
3. **Drift Detection**: Uses `scripts/test-drift.sh` to run `tofu plan -detailed-exitcode`. Fails on exit code 2 (unplanned changes or unmanaged resource mutations). A daily cron workflow (`tofu-drift.yml` at 06:00 UTC) actively monitors production for state drift.

## 3. Deployment Process

### Human Workflow
1. Create a `feature/<desc>` branch.
2. Edit `.tf` files. Follow naming and lifecycle policies.
3. Validate locally:
   ```bash
   tofu fmt
   tofu validate
   tofu plan
   ```
4. Push and open PR. The CI pipeline will surface drift or format issues.
5. Merge into `main` after approval. On-merge, Tofu changes apply automatically via `.github/workflows/tofu-apply.yml`.

### Agent (Hermes) Workflow
1. Execute inside the `cktom-cyou` repository. 
2. Use GitHub's dedicated proxy account tokens to generate plans without pulling sensitive files into the local trace unnecessarily (`NODE3_GHPROD_PLAN_TOKEN`, etc.).
3. When issuing PRs, include the output of `tofu plan` to guarantee the change is previewed and deterministic.
4. If testing scripts like `scripts/test-state.py` fall out of sync after a VM creation/deletion, update the `EXPECTED` resource mapping list in the python script in the same PR.

## 4. Recovering from failed state
- If drift alert fires: investigate changes via Proxmox UI. Either import into IaC (if canonical) or remove rogue manual modifications in UI to reset back to actual state. Run `./scripts/test-drift.sh` manually locally to verify recovery.
