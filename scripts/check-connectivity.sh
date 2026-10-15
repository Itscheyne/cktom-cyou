#!/usr/bin/env bash
# check-connectivity.sh — CI connectivity verification for Proxmox nodes over Netbird.
#
# Two phases:
#   1. Hard gate: netbird must report "Connected". If not, the mesh never came
#      up — dump diagnostics (netbird status -d, journalctl) and fail the job.
#      Nothing downstream can succeed without this, so this fails hard.
#   2. Soft probe: per-node reachability (ICMP ping, HTTPS probe to the
#      Proxmox VE API port 8006). Individual nodes are allowed to be
#      offline/decommissioned — the plan/apply/drift steps already handle
#      that with `-exclude=module.nodeN`. This phase only reports results to
#      GITHUB_STEP_SUMMARY and never fails the job; it exists purely to make
#      "why did node3 get excluded from this plan" visible without digging
#      through raw step logs.
#
# Usage:
#   ./scripts/check-connectivity.sh
#
# Reads NODE{1,2,3,4}_ENDPOINT from the environment (any subset may be unset).

set -uo pipefail

SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

echo "=== Netbird connectivity check ===" >&2

# --- Phase 1: Netbird mesh must be up -------------------------------------
NETBIRD_STATUS="$(sudo netbird status 2>&1 || true)"
echo "$NETBIRD_STATUS" >&2

if ! echo "$NETBIRD_STATUS" | grep -q "Connected"; then
  echo "::error::Netbird mesh is not connected — CI runner cannot reach Proxmox nodes"
  {
    echo "### Netbird connectivity check: FAILED"
    echo ""
    echo "Netbird did not report \"Connected\" status. Diagnostics below."
    echo ""
    echo "<details><summary>netbird status -d</summary>"
    echo ""
    echo '```'
    sudo netbird status -d 2>&1 || true
    echo '```'
    echo "</details>"
    echo ""
    echo "<details><summary>netbird service logs (journalctl)</summary>"
    echo ""
    echo '```'
    sudo journalctl -u netbird --no-pager -n 200 2>&1 || echo "(journalctl unavailable in this environment)"
    echo '```'
    echo "</details>"
  } >> "$SUMMARY"
  exit 1
fi

echo "Netbird mesh: Connected" >&2

# --- Phase 2: per-node reachability (non-fatal) -----------------------------
{
  echo "### Proxmox node connectivity"
  echo ""
  echo "| Node | Host | Ping | API probe (:8006) |"
  echo "|------|------|------|--------------------|"
} >> "$SUMMARY"

check_node() {
  local label="$1" endpoint="$2"
  [ -z "$endpoint" ] && return 0

  local host
  host=$(echo "$endpoint" | sed -e 's|https://||' -e 's|http://||' -e 's|:.*||' -e 's|/.*||')

  local ping_result api_result
  if ping -c 2 -W 2 "$host" >/dev/null 2>&1; then
    ping_result="ok"
  else
    ping_result="unreachable (icmp)"
  fi

  if curl -ksS --max-time 5 -o /dev/null -w "%{http_code}" "https://${host}:8006/api2/json/version" 2>/dev/null | grep -qE "^[0-9]{3}$"; then
    api_result="ok"
  else
    api_result="unreachable (api)"
  fi

  echo "| $label | $host | $ping_result | $api_result |" >> "$SUMMARY"
  echo "$label ($host): ping=$ping_result api=$api_result" >&2
}

check_node "node1" "${NODE1_ENDPOINT:-}"
check_node "node2" "${NODE2_ENDPOINT:-}"
check_node "node3" "${NODE3_ENDPOINT:-}"
check_node "node4" "${NODE4_ENDPOINT:-}"

echo "" >> "$SUMMARY"
echo "Unreachable nodes are expected to be excluded downstream via \`-exclude=module.nodeN\` (see tofu plan step); this check is diagnostic only." >> "$SUMMARY"

exit 0
