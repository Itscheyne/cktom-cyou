# OmniRoute Prometheus Exporter

Bridges OmniRoute's JSON REST metrics to Prometheus text format so Netdata's
`go.d/prometheus` collector can scrape them.

## Why this exists

OmniRoute has no native Prometheus / OTLP export — only JSON REST endpoints
gated behind a management bearer token.  Netdata's `httpcheck` collector
(PR #62) covers liveness/latency; this exporter provides deep metrics:
request counts, error rates, token usage, cache savings, per-combo latency,
circuit breaker state, and heap usage.

## Endpoints polled

| Endpoint                     | Auth  | Key metrics                                     |
|------------------------------|-------|-------------------------------------------------|
| `/api/monitoring/health`     | No    | `up`, `setup_complete`                          |
| `/api/monitoring/health`     | Yes   | `uptime`, `heap_*`, admission counters          |
| `/api/telemetry/summary`     | Yes   | `requests_total`, `errors_total`, `tokens_*`, latency |
| `/api/cache/stats`           | Yes   | semantic/prompt cache hit rate, tokens/cost saved |
| `/api/combos/metrics`        | Yes   | per-combo request counts and avg latency        |

## Exposed metrics (all prefixed `omniroute_`)

```
omniroute_up
omniroute_setup_complete
omniroute_uptime_seconds
omniroute_heap_used_bytes / omniroute_heap_total_bytes
omniroute_admitted_requests_total
omniroute_rejected_requests_total
omniroute_would_reject_requests_total
omniroute_admission_utilization
omniroute_circuit_breaker_open{provider=...}
omniroute_requests_total
omniroute_errors_total
omniroute_tokens_input_total / omniroute_tokens_output_total
omniroute_request_latency_avg_ms / _p95_ms / _p99_ms
omniroute_provider_requests_total{provider=...}
omniroute_semantic_cache_hits_total / _misses_total
omniroute_semantic_cache_hit_rate_percent
omniroute_semantic_cache_tokens_saved_total
omniroute_prompt_cache_requests_total
omniroute_prompt_cache_tokens_saved_total
omniroute_prompt_cache_cost_saved_usd
omniroute_combo_requests_total{combo=...}
omniroute_combo_latency_avg_ms{combo=...}
omniroute_exporter_last_scrape_unix
```

## Deployment

### 1. Build and push image

```bash
podman build -t ghcr.io/itscheyne/omniroute-exporter:latest ./netdata/omniroute-exporter/
podman push ghcr.io/itscheyne/omniroute-exporter:latest
```

Or build locally on prod3:

```bash
scp -r netdata/omniroute-exporter/ prod3:/tmp/omniroute-exporter/
ssh prod3 'podman build -t omniroute-exporter:local /tmp/omniroute-exporter/'
# Then update Image= in quadlet to omniroute-exporter:local
```

### 2. Create the bearer token secret on prod3

The management token is any valid OmniRoute API key with admin/management access.

```bash
printf '%s' 'YOUR_OMNIROUTE_MGMT_TOKEN' | podman secret create OMNIROUTE_MGMT_TOKEN -
```

To verify:
```bash
podman secret ls | grep OMNIROUTE_MGMT_TOKEN
```

### 3. Install the quadlet unit

```bash
cp quadlet/omniroute-exporter.container /etc/containers/systemd/
systemctl daemon-reload
systemctl start omniroute-exporter.service
systemctl status omniroute-exporter.service
```

### 4. Deploy Netdata go.d config

```bash
cp netdata/go.d/prometheus.conf /etc/netdata/go.d/prometheus.conf
systemctl restart netdata  # or: kill -HUP $(pgrep -f "netdata -D")
```

### 5. Verify metrics appear

```bash
# Check exporter is serving metrics
curl -s http://127.0.0.1:9877/metrics | grep omniroute_up

# Check Netdata picked them up (allow 1-2 scrape intervals)
curl -s "http://localhost:19999/api/v1/charts" | grep -i omniroute
```

## Environment variables

| Variable              | Default                                    | Description                          |
|-----------------------|--------------------------------------------|--------------------------------------|
| `OMNIROUTE_BASE_URL`  | `https://omniroute.prod.sf.cktom.cyou`     | OmniRoute base URL                   |
| `OMNIROUTE_MGMT_TOKEN`| (from secret)                              | Bearer token for auth endpoints      |
| `EXPORTER_PORT`       | `9877`                                     | Port to serve `/metrics` on          |
| `SCRAPE_INTERVAL`     | `30`                                       | Seconds between OmniRoute polls      |

## Notes

- Exporter binds to `127.0.0.1:9877` — not exposed externally.
- Auth endpoints (`telemetry/summary`, `cache/stats`, `combos/metrics`) silently
  skip and emit zero/absent metrics if the token is missing or invalid.
- The `go.d/prometheus` collector has a pre-existing `prometheus.conf` stale stub
  from task `t_12f95a64` — this file supersedes it.
