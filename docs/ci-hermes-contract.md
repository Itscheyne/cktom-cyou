# CI to Hermes Integration Contract

## Decision: Transport Mechanism
**Selected:** GitHub Issues

**Rationale:**
1. **Webhook:** Requires Hermes to host a publicly accessible HTTPS endpoint (or reverse proxy). Fails if Hermes is offline.
2. **Message Queue:** Over-engineered; requires external infrastructure (e.g., SQS, RabbitMQ).
3. **GitHub Issues (Winner):** Asynchronous, durable, requires no new infrastructure, and Hermes already has `github` skills to read and comment on issues. Human operators can also view the failures directly in the GitHub UI.

## Workflow
1. GitHub Actions `tofu-apply` job fails.
2. An `always()` or `failure()` step in the action gathers the failure details.
3. The action creates a new GitHub Issue (or comments on an existing open failure issue) labeled `ci-failure` and `agent-action-required`.
4. Hermes (polling or via GitHub App webhook) picks up the issue, reads the payload, creates a plan to fix the IaC, opens a PR, and comments on the issue with the PR link.

## API Contract / Payload Format

The GitHub Issue body will contain a structured JSON block wrapped in markdown for easy parsing by Hermes, followed by human-readable context.

### Issue Title
`[CI Failure] tofu-apply failed on branch: {branch_name}`

### Labels
- `ci-failure`
- `agent-action-required`

### Issue Body Template

```markdown
CI `tofu apply` failed. Please investigate and fix the infrastructure code.

### Automated Context
<!-- HERMES_PAYLOAD_START -->
```json
{
  "event": "ci_failure",
  "workflow": "tofu-apply",
  "run_id": 123456789,
  "repository": "itscheyne/cktom-cyou",
  "branch": "main",
  "commit_sha": "a1b2c3d4e5f6",
  "actor": "dependabot[bot]",
  "error_step": "tofu apply",
  "logs_summary": "Error: creating Proxmox Virtual Environment VM... \n\n<truncated log output>",
  "run_url": "https://github.com/itscheyne/cktom-cyou/actions/runs/123456789"
}
```
<!-- HERMES_PAYLOAD_END -->

### Error Logs
<details>
<summary>Click to view full failure log</summary>

```text
Include the raw stderr / stdout of the failed step here.
```
</details>
```

## Implementation Next Steps
1. **GitHub Actions (CI side):** Add a step at the end of `.github/workflows/tofu-apply.yml` that uses `gh issue create` or `actions/github-script` to POST this template on failure.
2. **Hermes (Agent side):** Implement an issue watcher (cron job or GitHub event listener) that looks for `agent-action-required`, extracts the JSON between `<!-- HERMES_PAYLOAD_START -->` and `<!-- HERMES_PAYLOAD_END -->`, creates a subtask, and processes the fix.
