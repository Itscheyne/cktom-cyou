# node3 + node4 only — skips node1 (frequently offline), the Talos-cluster-dependent
# longhorn resources, and the orphaned node1 SDN vnets. Use these when node1 is down.

# Things that depend on node1 being reachable or the Talos cluster being up:
EXCLUDE := \
	-exclude=module.node1 \
	-exclude=helm_release.longhorn \
	-exclude=kubernetes_namespace_v1.longhorn_system \
	-exclude=kubernetes_storage_class_v1.longhorn_default \
	 \
	 \
	 \
	

.PHONY: plan apply plan-all apply-all test test-drift test-state

# node3 + node4 only
plan:
	tofu plan $(EXCLUDE)

apply:
	tofu apply $(EXCLUDE)

# Everything, including node1 + Talos + longhorn (requires node1 online).
plan-all:
	tofu plan

apply-all:
	tofu apply

# ── Testing ──────────────────────────────────────────────────────────────────

# Run both tests (drift detection + state validation)
test: test-drift test-state

# Drift detection: fails if tofu plan shows any changes (exit 2 = drift).
test-drift:
	bash scripts/test-drift.sh

# State validation: assert expected resources exist with correct IDs/nodes.
# Requires live state (remote backend credentials must be available).
test-state:
	tofu show -json 2>/dev/null | python3 scripts/test-state.py
