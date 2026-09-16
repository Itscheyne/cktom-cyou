# Base image for tofu-plan / tofu-apply / tofu-drift CI jobs.
# Bundles OpenTofu + Netbird + the small CLI toolset those workflows shell out to,
# so per-run "Setup OpenTofu" / "Install netbird" steps can be dropped.
#
# Version bumps: bump TOFU_VERSION below and this file changes -> the
# build-tofu-ci-image workflow rebuilds and republishes automatically.

FROM ubuntu:24.04

ARG TOFU_VERSION=1.9.1

# ca-certificates/gnupg/curl: needed by the netbird install script and tofu installer.
# jq: used by CI scripts to parse plan/apply JSON.
# unzip: opentofu installer dependency.
# sudo: existing workflow steps call `sudo netbird up` / `sudo netbird status`.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        jq \
        sudo \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# OpenTofu, pinned to the version the CI workflows currently expect.
RUN curl -fsSL https://get.opentofu.org/install-opentofu.sh -o /tmp/install-opentofu.sh \
    && chmod +x /tmp/install-opentofu.sh \
    && /tmp/install-opentofu.sh --install-method standalone --opentofu-version "${TOFU_VERSION}" \
    && rm /tmp/install-opentofu.sh

# Netbird (mesh VPN client used to reach the Proxmox nodes from the runner).
# Upstream doesn't publish version-pinned installer args; tracked as-is to match
# current workflow behavior.
RUN curl -fsSL https://pkgs.netbird.io/install.sh | sh

RUN tofu version && netbird version

ENTRYPOINT ["/bin/bash"]
