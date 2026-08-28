# node3 + node4 only — skips node1 (frequently offline), the Talos-cluster-dependent
# longhorn resources, and the orphaned node1 SDN vnets. Use these when node1 is down.

# Things that depend on node1 being reachable or the Talos cluster being up:
EXCLUDE := \
	-exclude=module.node1 \
	-exclude=helm_release.longhorn \
	-exclude=kubernetes_namespace_v1.longhorn_system \
	-exclude=kubernetes_storage_class_v1.longhorn_default \
	-exclude=proxmox_sdn_vnet.node1 \
	-exclude=proxmox_virtual_environment_sdn_vnet.node1 \
	-exclude=proxmox_sdn_zone_simple.internal \
	-exclude=proxmox_virtual_environment_sdn_zone_simple.internal

.PHONY: plan apply plan-all apply-all

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
