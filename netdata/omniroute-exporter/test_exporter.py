"""Smoke test for exporter.py — runs collect_metrics() with no auth token."""
import os
import sys

os.environ["OMNIROUTE_BASE_URL"] = "https://omniroute.prod.sf.cktom.cyou"
os.environ["OMNIROUTE_MGMT_TOKEN"] = ""  # no auth — auth endpoints skip gracefully

sys.path.insert(0, os.path.dirname(__file__))
import exporter  # noqa: E402

text = exporter.collect_metrics()
lines = [l for l in text.split("\n") if l and not l.startswith("#")]
print(f"Metrics emitted: {len(lines)}")
for line in lines[:15]:
    print(" ", line)
print("...")
assert any("omniroute_up " in l for l in lines), "omniroute_up missing"
assert any("omniroute_exporter_last_scrape_unix" in l for l in lines), "scrape ts missing"
print("PASS")
