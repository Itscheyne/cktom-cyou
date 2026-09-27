# OmniRoute Netdata httpcheck monitoring

This directory contains the Netdata `go.d/httpcheck` configuration that
probes the OmniRoute API (`https://omniroute.prod.sf.cktom.cyou`) for
liveness, latency, and JSON-shape drift.

Deploy target: `/etc/netdata/go.d/httpcheck.conf` on the Netdata host
(node3 / `prod3.sf.cktom.cyou`). `quadlet/netdata.container` mounts
`/etc/netdata:/etc/netdata:Z`, so drop the file directly at that host
path and Netdata's go.d plugin auto-reloads it — no container rebuild
needed. If it doesn't pick up, restart the quadlet:
`sudo systemctl restart netdata.container`.

## Scope & limitations (read before extending this config)

`go.d/httpcheck` is a **synthetic liveness/latency prober, not a JSON
metrics scraper**. Every job in `httpcheck.conf` emits exactly Netdata's
four fixed httpcheck charts and nothing else:

| Chart | Dimensions | Meaning |
|---|---|---|
| `httpcheck.response_time` | `time` (ms) | round-trip latency |
| `httpcheck.response_length` | `length` (chars) | body size |
| `httpcheck.status` | `success, timeout, redirect, no_connection, bad_content, bad_header, bad_status` | outcome classification |
| `httpcheck.in_state` | `time` | seconds in current state |

`response_match` is a single regex tested against the raw body —
match/no-match only, no capture groups, no per-field extraction into a
chart. **This config cannot turn `totalCalls`, `budget.spend`,
`writeReadRatio`, per-model latency percentiles, etc. into their own
Netdata dimensions.** It can only tell you: is the endpoint up, how
fast did it respond, how big was the body, and does the response still
contain the JSON keys we expect (schema-drift alarm).

If per-field OmniRoute metrics (budget $, cache hit ratio, p99 latency
by model) are required as first-class Netdata charts, that needs a
different collector — e.g. a small custom OTLP/Prometheus exporter, or
a `pandas`/python.d module doing `read_json` + column selection — read
from these same endpoints. That is a follow-up decision for the user/
orchestrator, not solved by this file.

## Jobs

One job per requested endpoint (12 total), prefixed `omniroute_`. Job
names are used as chart labels — do not rename after first apply, it
breaks history continuity.

| Job | Endpoint | Auth | update_every | Notes |
|---|---|---|---|---|
| `omniroute_health` | `/api/monitoring/health` | none | 20s | public, no token attached (least privilege) |
| `omniroute_telemetry_summary` | `/api/telemetry/summary` | Bearer | 60s | in-memory aggregate |
| `omniroute_cache_stats` | `/api/cache/stats` | Bearer | 60s | in-memory aggregate |
| `omniroute_usage_budget` | `/api/usage/budget?apiKeyId=...` | Bearer | 60s | **requires editing the placeholder — see below** |
| `omniroute_usage_analytics` | `/api/usage/analytics?period=day` | Bearer | 300s | DB aggregation query |
| `omniroute_usage_history` | `/api/usage/history` | Bearer | 300s | DB aggregation query |
| `omniroute_usage_cache_health` | `/api/usage/cache-health?range=1h` | Bearer | 300s | DB aggregation query |
| `omniroute_usage_model_latency` | `/api/usage/model-latency-stats?windowHours=1&maxRows=100` | Bearer | 300s | DB aggregation query |
| `omniroute_usage_call_logs` | `/api/usage/call-logs?limit=1&offset=0` | Bearer | 300s | **raw log, connectivity check only** |
| `omniroute_usage_logs` | `/api/usage/logs?limit=1` | Bearer | 300s | **raw log, connectivity check only** |
| `omniroute_usage_proxy_logs` | `/api/usage/proxy-logs?limit=1` | Bearer | 300s | **raw log, connectivity check only** |
| `omniroute_usage_request_logs` | `/api/usage/request-logs?limit=1` | Bearer | 300s | **raw log, connectivity check only** |

The four raw-log jobs intentionally have **no `response_match`** — their
bodies can contain prompts, tokens, and user/session identifiers.
httpcheck has no field-extraction capability, so there's nothing to gain
by inspecting the body and every reason not to. They're checked for
`200` status only, at a low cadence (300s), to confirm the endpoint is
reachable without hammering the backend or transferring sensitive
payloads more than necessary.

## `apiKeyId` placeholder (not a secret — but requires a decision)

`omniroute_usage_budget` needs a mandatory `apiKeyId` query parameter —
this identifies *which* OmniRoute API key's budget to report on, it is
not a credential. The shipped config has:

```
url: https://omniroute.prod.sf.cktom.cyou/api/usage/budget?apiKeyId=REPLACE_WITH_API_KEY_ID
```

Before deploying, either:
- replace `REPLACE_WITH_API_KEY_ID` with the specific key ID you want
  tracked, or
- comment out / delete the `omniroute_usage_budget` job if no single
  key is representative of "the" budget you care about (e.g. if you
  have many keys and want per-key budget dashboards, that's multiple
  jobs or a different collector — a decision for the user, not made
  here).

## Authentication / secret provisioning (do this yourself — agents are secret-blind)

**No token is committed to this repo or written by any agent.** The
config only references a file path (`bearer_token_file`), resolved at
runtime by the Netdata agent process itself.

1. In OmniRoute, provision a dedicated, least-privilege Access Token
   (Settings → Access Tokens, prefix `oma_live_…`) scoped for
   read/monitoring only — not a full `admin` key. If OmniRoute has no
   read-only scope tier yet, use the minimum scope that satisfies these
   routes (`manage`, per the OpenAPI spec) and treat it as a sensitive
   infra credential, rotated on the same cadence as other prod secrets.

2. On the Netdata host (node3), drop the raw token value at a
   root-only, netdata-owned path:

   ```bash
   install -o netdata -g netdata -m 0440 /dev/stdin /etc/netdata/secrets/omniroute_token <<< "oma_live_xxxxxxxx"
   ```

   (Follow whatever secret-drop convention the Netdata quadlet already
   uses for `NETDATA_CLAIM_TOKEN` if that differs — e.g. podman
   `Secret=` mounted read-only. Never bake the token into the image or
   commit it to git.)

3. `httpcheck.conf` already references this path via:

   ```yaml
   bearer_token_file: /etc/netdata/secrets/omniroute_token
   ```

   No further config edits needed once the file exists at that path.

4. `omniroute_health` deliberately carries no credential — it's a
   public endpoint, and there's no reason to send a bearer token to a
   route that doesn't need one (least privilege).

5. Never set `username`/`password` (Basic auth) — OmniRoute uses
   Bearer, not Basic.

## Failure / alerting

Netdata ships default alarm templates keyed on the `httpcheck` context
family (`httpcheck_web_service_up`, `_bad_content`, `_bad_status`,
`_bad_header`, `_timeouts`, `_no_connection`) — these apply
automatically per job once this file lands, no custom health config
required for day one.

Recommendations for a follow-up custom health config:
- Don't alert on the four raw-log jobs at the same severity as
  `omniroute_health` / `omniroute_usage_budget` — they're
  diagnostic/audit surfaces; demote to `warning`-only.
- A `bad_status` on any authenticated job most likely means `401`/`403`
  (token expired/revoked/rotated) rather than an OmniRoute outage —
  worth a distinct runbook note so on-call doesn't mistake an expired
  token for a service outage.
- A sustained `bad_content` (the `response_match` field-name regex
  stops matching) is a contract-drift signal — OmniRoute changed a
  response shape — should page whoever owns a future JSON-metric
  collector, since anything built on those field names downstream would
  break too.

## Data-safety summary

- httpcheck **never stores or charts response bodies** — its only
  body-derived numeric output is `response_length` (byte/char count)
  and the boolean match result of `response_match`. No prompt text,
  token, user ID, or log line is ever written to a chart, dimension
  label, or (at default log level) an agent log line.
- No capture groups are used in any `response_match`; regexes only
  assert presence of a known JSON key name (e.g. `"status"`,
  `"verdict"`), never a value.
- The four raw-log endpoints are checked for connectivity (status code)
  only — never regex-matched against body content.
- No secret is stored in `httpcheck.conf` — it only references a path
  resolved at runtime by the Netdata agent process itself.
- `omniroute_health` intentionally carries no credential at all.

## References

- Endpoint inventory: OMNIROUTE_API_METRICS_INVENTORY.md (task
  t_5160bbc4)
- Collector design rationale: HTTPCHECK_DESIGN.md (task t_60357ff1,
  originally drafted here, superseded by this README + the shipped
  `httpcheck.conf`)
- Upstream module docs: https://github.com/netdata/netdata/tree/master/src/go/plugin/go.d/collector/httpcheck
