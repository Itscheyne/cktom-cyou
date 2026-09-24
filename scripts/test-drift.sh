#!/usr/bin/env bash
# test-drift.sh — Drift detection for node3 + node4 IaC.
#
# Runs `tofu plan -detailed-exitcode` and fails if any changes are detected.
# Exit codes:
#   0  — no changes (clean state, no drift)
#   1  — tofu error (config/provider failure)
#   2  — changes detected (drift or unmanaged resource change)
#
# Usage:
#   ./scripts/test-drift.sh                   # node3 + node4 only (default)
#   ./scripts/test-drift.sh --all             # include node1 + Talos + longhorn
#   TOFU_PLAN_FLAGS="..." ./scripts/test-drift.sh
#
# Expects tfvars already present (ci.auto.tfvars or terraform.tfvars).

set -euo pipefail

ALL=false
for arg in "$@"; do
  [ "$arg" = "--all" ] && ALL=true
done

# Build exclude flags (node3+node4 mode excludes everything node1/Talos dependent)
EXCLUDE_FLAGS=""
if [ "$ALL" = "false" ]; then
  EXCLUDE_FLAGS="\
    -exclude=module.node1 \
    -exclude=helm_release.longhorn \
    -exclude=kubernetes_namespace_v1.longhorn_system \
    -exclude=kubernetes_storage_class_v1.longhorn_default \
    -exclude=proxmox_sdn_vnet.node1 \
    -exclude=proxmox_virtual_environment_sdn_vnet.node1 \
    -exclude=proxmox_sdn_zone_simple.internal \
    -exclude=proxmox_virtual_environment_sdn_zone_simple.internal"
fi

# Extra flags from environment (e.g. -exclude=module.node3 if unreachable)
EXTRA="${TOFU_PLAN_FLAGS:-}"

echo "=== IaC Drift Detection ==="
echo "Scope: $([ "$ALL" = "true" ] && echo 'all' || echo 'node3+node4')"
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# Run plan with -detailed-exitcode
# Exit 0 = no changes, exit 2 = changes present, exit 1 = error
set +e
tofu plan -detailed-exitcode -input=false -out=tfplan.binary \
  $EXCLUDE_FLAGS $EXTRA
PLAN_EXIT=$?
set -e

case $PLAN_EXIT in
  0)
    echo ""
    echo "PASS: No changes detected. State matches live cluster."
    # Keep tfplan.binary — the caller's "State validation" step needs it
    # (tofu show -json tfplan.binary) and cleans it up itself.
    exit 0
    ;;
  2)
    echo ""
    echo "FAIL: Changes detected — infrastructure has drifted from IaC state."
    echo "Review the plan above. Either:"
    echo "  1. Apply the plan to reconcile: tofu apply tfplan.binary"
    echo "  2. Update IaC to match intentional runtime changes."
    rm -f tfplan.binary
    exit 2
    ;;
  *)
    echo ""
    echo "ERROR: tofu plan failed (exit $PLAN_EXIT). Check provider connectivity."
    rm -f tfplan.binary
    exit 1
    ;;
esac
