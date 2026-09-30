#!/usr/bin/env python3
"""
OmniRoute Prometheus Exporter
Polls OmniRoute JSON REST endpoints and exposes metrics in Prometheus text format.

Endpoints polled:
  GET /api/monitoring/health     (no auth)
  GET /api/telemetry/summary     (bearer)
  GET /api/combos/metrics        (bearer)
  GET /api/cache/stats           (bearer)

Serves: GET /metrics  on EXPORTER_PORT (default 9877)
"""

import os
import time
import logging
import urllib.request
import urllib.error
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from threading import Lock

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
log = logging.getLogger("omniroute-exporter")

OMNIROUTE_BASE = os.environ.get("OMNIROUTE_BASE_URL", "https://omniroute.prod.sf.cktom.cyou")
OMNIROUTE_TOKEN = os.environ.get("OMNIROUTE_MGMT_TOKEN", "")
SCRAPE_INTERVAL = int(os.environ.get("SCRAPE_INTERVAL", "30"))
EXPORTER_PORT = int(os.environ.get("EXPORTER_PORT", "9877"))

_metrics_lock = Lock()
_metrics_text = ""
_last_error = None


def _fetch(path: str, auth: bool = False) -> dict:
    url = f"{OMNIROUTE_BASE}{path}"
    req = urllib.request.Request(url)
    req.add_header("Accept", "application/json")
    if auth and OMNIROUTE_TOKEN:
        req.add_header("Authorization", f"Bearer {OMNIROUTE_TOKEN}")
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode())


def _safe_float(v, default=0.0) -> float:
    try:
        return float(v)
    except (TypeError, ValueError):
        return default


def collect_metrics() -> str:
    lines: list[str] = []

    # ------------------------------------------------------------------
    # /api/monitoring/health  (no auth required)
    # ------------------------------------------------------------------
    try:
        h = _fetch("/api/monitoring/health", auth=False)
        up = 1 if h.get("status") == "healthy" else 0
        lines += [
            "# HELP omniroute_up OmniRoute service health (1=healthy, 0=unhealthy)",
            "# TYPE omniroute_up gauge",
            f"omniroute_up {up}",
            "# HELP omniroute_setup_complete Setup wizard completed",
            "# TYPE omniroute_setup_complete gauge",
            f"omniroute_setup_complete {1 if h.get('setupComplete') else 0}",
        ]
    except Exception as exc:
        log.warning("health fetch failed: %s", exc)
        lines += [
            "# HELP omniroute_up OmniRoute service health (1=healthy, 0=unhealthy)",
            "# TYPE omniroute_up gauge",
            "omniroute_up 0",
        ]

    # ------------------------------------------------------------------
    # /api/monitoring/health (extended — same endpoint, different fields)
    # from the mgmt health endpoint which returns full health object
    # ------------------------------------------------------------------
    try:
        mh = _fetch("/api/monitoring/health", auth=True)
        uptime = _safe_float(mh.get("uptime"))
        heap_used = _safe_float(mh.get("memoryUsage", {}).get("heapUsed"))
        heap_total = _safe_float(mh.get("memoryUsage", {}).get("heapTotal"))
        aa = mh.get("adaptiveAdmission", {})
        admitted = _safe_float(aa.get("admittedCount"))
        rejected = _safe_float(aa.get("rejectedCount"))
        would_reject = _safe_float(aa.get("wouldRejectCount"))
        utilization = _safe_float(aa.get("utilization"))

        lines += [
            "",
            "# HELP omniroute_uptime_seconds Process uptime in seconds",
            "# TYPE omniroute_uptime_seconds counter",
            f"omniroute_uptime_seconds {uptime}",
            "",
            "# HELP omniroute_heap_used_bytes V8 heap used bytes",
            "# TYPE omniroute_heap_used_bytes gauge",
            f"omniroute_heap_used_bytes {heap_used}",
            "",
            "# HELP omniroute_heap_total_bytes V8 heap total bytes",
            "# TYPE omniroute_heap_total_bytes gauge",
            f"omniroute_heap_total_bytes {heap_total}",
            "",
            "# HELP omniroute_admitted_requests_total Total admitted requests (adaptive admission)",
            "# TYPE omniroute_admitted_requests_total counter",
            f"omniroute_admitted_requests_total {admitted}",
            "",
            "# HELP omniroute_rejected_requests_total Total rejected requests (adaptive admission)",
            "# TYPE omniroute_rejected_requests_total counter",
            f"omniroute_rejected_requests_total {rejected}",
            "",
            "# HELP omniroute_would_reject_requests_total Requests that would have been rejected",
            "# TYPE omniroute_would_reject_requests_total counter",
            f"omniroute_would_reject_requests_total {would_reject}",
            "",
            "# HELP omniroute_admission_utilization Admission utilization ratio (0–1)",
            "# TYPE omniroute_admission_utilization gauge",
            f"omniroute_admission_utilization {utilization}",
        ]

        cbs = mh.get("circuitBreakers", [])
        lines += [
            "",
            "# HELP omniroute_circuit_breaker_open Circuit breaker open (1=open, 0=closed) by provider",
            "# TYPE omniroute_circuit_breaker_open gauge",
        ]
        for cb in cbs:
            provider = cb.get("provider", "unknown").replace('"', "")
            state = 1 if cb.get("state") == "open" else 0
            lines.append(f'omniroute_circuit_breaker_open{{provider="{provider}"}} {state}')
        if not cbs:
            # no breakers — emit a sentinel so the chart still initialises
            lines.append('omniroute_circuit_breaker_open{provider="none"} 0')

    except Exception as exc:
        log.warning("extended health fetch failed: %s", exc)

    # ------------------------------------------------------------------
    # /api/telemetry/summary  (auth required)
    # ------------------------------------------------------------------
    try:
        ts = _fetch("/api/telemetry/summary", auth=True)
        total_req = _safe_float(ts.get("totalRequests"))
        total_err = _safe_float(ts.get("totalErrors"))
        total_tokens_in = _safe_float(ts.get("totalTokensIn"))
        total_tokens_out = _safe_float(ts.get("totalTokensOut"))
        avg_latency = _safe_float(ts.get("avgLatencyMs"))
        p95_latency = _safe_float(ts.get("p95LatencyMs"))
        p99_latency = _safe_float(ts.get("p99LatencyMs"))

        lines += [
            "",
            "# HELP omniroute_requests_total Total requests processed",
            "# TYPE omniroute_requests_total counter",
            f"omniroute_requests_total {total_req}",
            "",
            "# HELP omniroute_errors_total Total request errors",
            "# TYPE omniroute_errors_total counter",
            f"omniroute_errors_total {total_err}",
            "",
            "# HELP omniroute_tokens_input_total Total input tokens consumed",
            "# TYPE omniroute_tokens_input_total counter",
            f"omniroute_tokens_input_total {total_tokens_in}",
            "",
            "# HELP omniroute_tokens_output_total Total output tokens produced",
            "# TYPE omniroute_tokens_output_total counter",
            f"omniroute_tokens_output_total {total_tokens_out}",
            "",
            "# HELP omniroute_request_latency_avg_ms Average request latency milliseconds",
            "# TYPE omniroute_request_latency_avg_ms gauge",
            f"omniroute_request_latency_avg_ms {avg_latency}",
            "",
            "# HELP omniroute_request_latency_p95_ms P95 request latency milliseconds",
            "# TYPE omniroute_request_latency_p95_ms gauge",
            f"omniroute_request_latency_p95_ms {p95_latency}",
            "",
            "# HELP omniroute_request_latency_p99_ms P99 request latency milliseconds",
            "# TYPE omniroute_request_latency_p99_ms gauge",
            f"omniroute_request_latency_p99_ms {p99_latency}",
        ]

        # Per-provider breakdown if present
        providers = ts.get("byProvider", {})
        if providers:
            lines += [
                "",
                "# HELP omniroute_provider_requests_total Requests by provider",
                "# TYPE omniroute_provider_requests_total counter",
            ]
            for prov, pdata in providers.items():
                p = prov.replace('"', "")
                cnt = _safe_float(pdata.get("requests") if isinstance(pdata, dict) else pdata)
                lines.append(f'omniroute_provider_requests_total{{provider="{p}"}} {cnt}')

    except Exception as exc:
        log.warning("telemetry/summary fetch failed: %s", exc)

    # ------------------------------------------------------------------
    # /api/cache/stats  (auth required)
    # ------------------------------------------------------------------
    try:
        cs = _fetch("/api/cache/stats", auth=True)
        sc = cs.get("semanticCache", {})
        pc = cs.get("promptCache", {})

        sc_hits = _safe_float(sc.get("hits"))
        sc_misses = _safe_float(sc.get("misses"))
        sc_hit_rate = _safe_float(sc.get("hitRate"))
        sc_tokens_saved = _safe_float(sc.get("tokensSaved"))

        pc_total_req = _safe_float(pc.get("totalRequests"))
        pc_cached_tokens = _safe_float(pc.get("totalCachedTokens"))
        pc_tokens_saved = _safe_float(pc.get("tokensSaved"))
        pc_cost_saved = _safe_float(pc.get("estimatedCostSaved"))

        lines += [
            "",
            "# HELP omniroute_semantic_cache_hits_total Semantic cache hits",
            "# TYPE omniroute_semantic_cache_hits_total counter",
            f"omniroute_semantic_cache_hits_total {sc_hits}",
            "",
            "# HELP omniroute_semantic_cache_misses_total Semantic cache misses",
            "# TYPE omniroute_semantic_cache_misses_total counter",
            f"omniroute_semantic_cache_misses_total {sc_misses}",
            "",
            "# HELP omniroute_semantic_cache_hit_rate_percent Semantic cache hit rate percent",
            "# TYPE omniroute_semantic_cache_hit_rate_percent gauge",
            f"omniroute_semantic_cache_hit_rate_percent {sc_hit_rate}",
            "",
            "# HELP omniroute_semantic_cache_tokens_saved_total Tokens saved by semantic cache",
            "# TYPE omniroute_semantic_cache_tokens_saved_total counter",
            f"omniroute_semantic_cache_tokens_saved_total {sc_tokens_saved}",
            "",
            "# HELP omniroute_prompt_cache_requests_total Total requests hitting prompt cache",
            "# TYPE omniroute_prompt_cache_requests_total counter",
            f"omniroute_prompt_cache_requests_total {pc_total_req}",
            "",
            "# HELP omniroute_prompt_cache_tokens_saved_total Input tokens saved by prompt cache",
            "# TYPE omniroute_prompt_cache_tokens_saved_total counter",
            f"omniroute_prompt_cache_tokens_saved_total {pc_tokens_saved}",
            "",
            "# HELP omniroute_prompt_cache_cost_saved_usd Estimated cost saved by prompt cache (USD)",
            "# TYPE omniroute_prompt_cache_cost_saved_usd counter",
            f"omniroute_prompt_cache_cost_saved_usd {pc_cost_saved}",
        ]
    except Exception as exc:
        log.warning("cache/stats fetch failed: %s", exc)

    # ------------------------------------------------------------------
    # /api/combos/metrics  (auth required)
    # ------------------------------------------------------------------
    try:
        cm = _fetch("/api/combos/metrics", auth=True)
        combos = cm if isinstance(cm, list) else cm.get("combos", [])
        if combos:
            lines += [
                "",
                "# HELP omniroute_combo_requests_total Total requests by combo",
                "# TYPE omniroute_combo_requests_total counter",
            ]
            for c in combos:
                name = str(c.get("name", c.get("id", "unknown"))).replace('"', "")
                cnt = _safe_float(c.get("requestCount", c.get("requests", 0)))
                lines.append(f'omniroute_combo_requests_total{{combo="{name}"}} {cnt}')

            lines += [
                "",
                "# HELP omniroute_combo_latency_avg_ms Average latency per combo (ms)",
                "# TYPE omniroute_combo_latency_avg_ms gauge",
            ]
            for c in combos:
                name = str(c.get("name", c.get("id", "unknown"))).replace('"', "")
                lat = _safe_float(c.get("avgLatencyMs", 0))
                lines.append(f'omniroute_combo_latency_avg_ms{{combo="{name}"}} {lat}')
    except Exception as exc:
        log.warning("combos/metrics fetch failed: %s", exc)

    # Scrape timestamp
    lines += [
        "",
        "# HELP omniroute_exporter_last_scrape_unix Unix timestamp of last successful scrape",
        "# TYPE omniroute_exporter_last_scrape_unix gauge",
        f"omniroute_exporter_last_scrape_unix {time.time():.0f}",
    ]

    return "\n".join(lines) + "\n"


def scrape_loop():
    global _metrics_text, _last_error
    while True:
        try:
            text = collect_metrics()
            with _metrics_lock:
                _metrics_text = text
                _last_error = None
            log.debug("scrape OK, %d bytes", len(text))
        except Exception as exc:
            log.error("scrape error: %s", exc)
            with _metrics_lock:
                _last_error = str(exc)
        time.sleep(SCRAPE_INTERVAL)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):  # noqa: A002
        pass  # suppress access logs

    def do_GET(self):
        if self.path not in ("/metrics", "/metrics/"):
            self.send_response(404)
            self.end_headers()
            return
        with _metrics_lock:
            body = _metrics_text.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    import threading

    log.info("OmniRoute Prometheus exporter starting on port %d", EXPORTER_PORT)
    log.info("Polling %s every %ds", OMNIROUTE_BASE, SCRAPE_INTERVAL)

    # Collect once synchronously before accepting requests
    try:
        initial = collect_metrics()
        with _metrics_lock:
            _metrics_text = initial
    except Exception as e:
        log.warning("Initial scrape failed: %s", e)

    t = threading.Thread(target=scrape_loop, daemon=True)
    t.start()

    server = HTTPServer(("0.0.0.0", EXPORTER_PORT), Handler)
    server.serve_forever()
