#!/usr/bin/env python3
"""Poll GitHub for CI-failure issues and open a Hermes kanban fix task.

Implements the Hermes-side half of the CI -> Hermes feedback loop described
in docs/ci-hermes-contract.md. The GitHub Actions `tofu-apply` workflow opens
an issue labeled `ci-failure` + `agent-action-required` with a JSON payload
block on failure (see .github/workflows/tofu-apply.yml). This script:

  1. Lists open issues in the repo labeled `agent-action-required`.
  2. Extracts the JSON between the HERMES_PAYLOAD_START/END markers.
  3. Creates a Hermes kanban task (assignee: ops-infrastructure) to
     investigate and fix the infrastructure code, idempotency-keyed on the
     issue number so re-runs never double-create.
  4. Comments on the issue with the task id and relabels it
     agent-action-required -> hermes-processing so it isn't reprocessed.

Designed to run under `hermes cron ... --no-agent --script <this file>`:
empty stdout = nothing to do (silent, no notification), non-empty stdout =
summary of issues processed, non-zero exit = alert (hard failure).

Requires: `gh` and `hermes` on PATH, `gh` authenticated (or GITHUB_TOKEN /
GH_TOKEN set) with repo scope.

Env:
  CI_ISSUE_REPO   owner/repo to watch (default: itscheyne/cktom-cyou)
  CI_FIX_ASSIGNEE Hermes profile to assign fix tasks to (default: ops-infrastructure)
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys

REPO = os.environ.get("CI_ISSUE_REPO", "itscheyne/cktom-cyou")
ASSIGNEE = os.environ.get("CI_FIX_ASSIGNEE", "ops-infrastructure")
LABEL_TRIGGER = "agent-action-required"
LABEL_DONE = "hermes-processing"

PAYLOAD_RE = re.compile(
    r"<!--\s*HERMES_PAYLOAD_START\s*-->\s*```json\s*(\{.*?\})\s*```\s*<!--\s*HERMES_PAYLOAD_END\s*-->",
    re.DOTALL,
)


def run(cmd: list[str]) -> str:
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"{' '.join(cmd)} failed (rc={result.returncode}): {result.stderr.strip()}")
    return result.stdout


def list_issues() -> list[dict]:
    raw = run([
        "gh", "issue", "list",
        "--repo", REPO,
        "--label", LABEL_TRIGGER,
        "--state", "open",
        "--json", "number,title,body,url",
    ])
    return json.loads(raw or "[]")


def extract_payload(body: str) -> dict:
    m = PAYLOAD_RE.search(body or "")
    if not m:
        return {}
    try:
        return json.loads(m.group(1))
    except json.JSONDecodeError:
        return {}


def create_fix_task(issue: dict) -> str:
    number = issue["number"]
    payload = extract_payload(issue.get("body", ""))
    branch = payload.get("branch", "unknown")
    run_url = payload.get("run_url", issue.get("url", ""))
    logs = (payload.get("logs_summary") or "")[:3000]
    commit_sha = payload.get("commit_sha", "")

    title = f"Fix CI failure: tofu apply on {branch} (issue #{number})"
    body = (
        f"GitHub Actions `tofu-apply` failed on branch `{branch}`"
        + (f" (commit {commit_sha})" if commit_sha else "")
        + ".\n\n"
        f"Run: {run_url}\n"
        f"Source issue: {issue.get('url', '')}\n\n"
        "### Error log summary\n```\n" + (logs or "No log summary provided.") + "\n```\n\n"
        "Investigate and fix the OpenTofu infrastructure code, then open a PR. "
        f"Comment on issue #{number} in {REPO} with the PR link when done, and "
        "close the issue once merged."
    )

    out = run([
        "hermes", "kanban", "create",
        "--json",
        "--assignee", ASSIGNEE,
        "--workspace", "worktree",
        "--priority", "1",
        "--idempotency-key", f"ci-issue-{REPO}-{number}",
        "--body", body,
        title,
    ])
    task = json.loads(out)
    return task["id"]


def mark_processed(number: int, task_id: str) -> None:
    run([
        "gh", "issue", "comment", str(number),
        "--repo", REPO,
        "--body", f"Hermes task created: `{task_id}` (assignee: {ASSIGNEE}). Tracking the fix there.",
    ])
    run([
        "gh", "issue", "edit", str(number),
        "--repo", REPO,
        "--remove-label", LABEL_TRIGGER,
        "--add-label", LABEL_DONE,
    ])


def main() -> int:
    try:
        issues = list_issues()
    except RuntimeError as exc:
        print(f"hermes_ci_issue_watcher: {exc}", file=sys.stderr)
        return 1

    if not issues:
        return 0  # nothing new: stay silent

    summary_lines = []
    for issue in issues:
        number = issue["number"]
        try:
            task_id = create_fix_task(issue)
            mark_processed(number, task_id)
            summary_lines.append(f"- issue #{number} -> task {task_id} (assignee: {ASSIGNEE})")
        except RuntimeError as exc:
            print(f"hermes_ci_issue_watcher: failed on issue #{number}: {exc}", file=sys.stderr)
            # Don't relabel on failure — leave it for the next tick / a human.
            continue

    if summary_lines:
        print("Hermes CI feedback loop: opened fix tasks for new CI failures:\n" + "\n".join(summary_lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
