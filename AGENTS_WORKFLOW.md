# Multi-Agent Git Workflow for IaC

Agents working independently on the same Infrastructure as Code (IaC) repository can quickly cause merge conflicts, clobbered changes, and broken state if they don't coordinate. This document outlines the workflow and conventions to prevent these issues.

## 1. Branch Naming & Scoping

*   **Convention:** `agent/<profile_name>/<task_id>-<short_desc>`
    *   Example: `agent/ops-infrastructure/t_91b10b76-git-workflow`
*   **Scope:** One task = one branch = one Pull Request. Do not bundle unrelated changes.
*   **Size:** Keep PRs small and focused. Smaller diffs are easier to review and less likely to conflict.

## 2. File & Directory Ownership (Soft Locks)

Given the structure of our Proxmox OpenTofu repository, true file locking is difficult, but we can establish logical ownership:

*   **Node-Specific Files:** (`node3.tf`, `node4.tf`)
    *   Changes should ideally be isolated to individual resources.
    *   If task A creates a VM on `node3` and task B modifies a different VM on `node3`, they will likely touch the same file but different blocks.
    *   **Rule:** If a PR touches a file, subsequent tasks touching the *same file* should wait for the first PR to merge if they modify the same resource block.
*   **Global Configuration:** (`variables.tf`, `providers.tf`, `networking.tf`, `pools.tf`)
    *   These are high-friction files. Changes here affect the entire cluster.
    *   **Rule:** Limit concurrent PRs touching global configuration. If a network configuration PR is open, block other network-related tasks until it merges.

## 3. Coordination & Collision Avoidance

*   **Pre-Flight Check:** Before starting work, agents must check for open PRs affecting their target files.
    *   Command: `gh pr list --state open --json number,title,files` (or equivalent API call).
*   **Kanban Board Hotspots:**
    *   If an agent detects a significant overlap with an existing, unrelated task, they must use a `kanban_comment` containing `hotspot: <filepath> - <reason>`.
    *   The orchestrator must use these hotspot signals to serialize tasks touching the same files.
*   **The Orchestrator's Role:**
    *   The orchestrator is responsible for dependency mapping. If Task B depends on Task A (or touches the same high-friction files), the orchestrator must add Task A as a parent of Task B in the Kanban board (`parents=[task-a-id]`).

## 4. The Pull Request Lifecycle

1.  **Branch:** Create branch from latest `main`.
2.  **Act:** Implement changes, format (`tofu fmt`), and validate (`tofu validate`).
3.  **Preview:** Run `tofu plan` to generate evidence of safety.
4.  **Confirm Sync:** **Rebase** on `main` immediately before opening the PR.
    *   `git fetch origin main`
    *   `git rebase origin/main`
    *   This ensures the plan is accurate against the current cluster state.
5.  **Open PR:** Include the `tofu plan` output and a clear summary in the PR body.
6.  **CI Gate:** A GitHub Action MUST run `tofu plan` on the PR to independently verify the changes against the remote state. (This prevents agents from faking plan outputs).
7.  **Merge:**
    *   **Merge Queue:** Strongly recommended. Use GitHub's built-in Merge Queue or a tool like Mergify.
    *   **Requirement:** Branches *must* be up to date with `main` before merging. If `main` advances while a PR is pending, the agent (or CI bot) must rebase the PR.

## Workflow Diagram

```ascii
Orchestrator -> Decomposes Task -> Sub-task to Agent
                                         |
                                         V
                                Check for Hotspots (Open PRs on target files)
                                         |
                            [Conflict?]--+--[No Conflict?]
                                 |                |
                                 V                V
                        Add Kanban Block   Update local `main`
                        (Wait for merge)        |
                                                  V
                                           Branch: agent/<profile>/<task>
                                                  |
                                                  V
                                           Make Changes
                                                  |
                                           tofu fmt & validate
                                                  |
                                                  V
                                         Fetch & Rebase `main`
                                                  |
                                                  V
                                              tofu plan
                                                  |
                                                  V
                                           Open Pull Request
                                           (Include Plan Output)
                                                  |
                                                  V
                                           CI Plan Verification
                                                  |
                                                  V
                                          [Review / Merge Queue] -> Merged to `main`
```

## Recommended Tooling

1.  **GitHub Merge Queue:** Enable this in branch protection rules. It automatically updates branches and ensures they pass CI before merging, serializing updates and preventing logical conflicts that Git might miss.
2.  **Branch Protection Rules:**
    *   Require linear history (force rebasing, no merge commits).
    *   Require status checks to pass before merging (specifically the `tofu plan` CI job).
    *   Require pull request reviews (even if just self-reviewed or reviewed by a human operator acting as a gate).
3.  **`gh` CLI Integration:** Agents should have the `gh` CLI configured to interact with issues and PRs natively.
