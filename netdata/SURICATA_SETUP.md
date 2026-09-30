# Suricata Metrics: Setup Guide

Two Suricata instances feed Netdata on prod3:

1. OPNSense IPS (10.0.4.1)  — via opnsense-exporter container on prod3
2. Security Onion IDS (so-oc, node3/VM 501)  — via corelight/suricata_exporter on so-oc

---

## Part 1: OPNSense IPS (largely automated)

### 1.1  OPNSense: Create API key

1. Log into OPNSense at https://10.0.4.1
2. System > Access > Users  — edit the user you want to use (or create a new one)
3. Scroll to API keys section, click "+" to generate key+secret pair.
   The secret is shown only once — copy it immediately.
4. Assign the user to a group with at least these privileges:
     Firewall: Aliases (read)
     Intrusion Detection (read)
     Diagnostics: Interface (read)
     Status: Gateways (read)

### 1.2  prod3: Store credentials as podman secrets

SSH into prod3 and run:

    printf '%s' 'PASTE_API_KEY_HERE'    | podman secret create OPNSENSE_API_KEY -
    printf '%s' 'PASTE_API_SECRET_HERE' | podman secret create OPNSENSE_API_SECRET -

### 1.3  prod3: Deploy the quadlet

Copy or sync quadlet/opnsense-exporter.container to prod3 at the quadlet service path
(same directory as other .container files, typically
  /home/<user>/.config/containers/systemd/  or
  /etc/containers/systemd/ for system-level):

    # Reload systemd and start
    systemctl --user daemon-reload
    systemctl --user start opnsense-exporter.service
    systemctl --user enable opnsense-exporter.service

    # Verify
    curl -s http://127.0.0.1:9100/metrics | grep opnsense_up

### 1.4  prod3: Update prometheus.conf

Copy netdata/go.d/prometheus.conf to /etc/netdata/go.d/prometheus.conf on prod3
(or let the quadlet/deployment pipeline sync it — Netdata container mounts /etc/netdata).

Restart the netdata container to pick up the new scrape jobs:

    systemctl --user restart netdata.service

---

## Part 2: Security Onion IDS (manual install on so-oc)

Security Onion runs Suricata in IDS mode with EVE JSON. The corelight/suricata_exporter
connects to Suricata's unix control socket and exposes Prometheus metrics on port 9917.

### 2.1  Prerequisites on so-oc

Suricata must have the unix command socket enabled. Check /etc/suricata/suricata.yaml:

    unix-command:
      enabled: yes
      filename: /var/run/suricata.socket

If not enabled, add/uncomment it and restart Suricata:

    sudo systemctl restart suricata

### 2.2  Install suricata_exporter on so-oc

SSH into so-oc (find its VLAN-3 IP first — check DHCP leases on OPNSense or run
"ip addr" on the VM via Proxmox console for VM 501 on node3).

Option A — Pre-built binary from GitHub releases:

    # Find latest release at https://github.com/corelight/suricata_exporter/releases
    VERSION=v0.6.0   # update to latest
    curl -sSL "https://github.com/corelight/suricata_exporter/releases/download/${VERSION}/suricata_exporter_linux_amd64" \
         -o /usr/local/bin/suricata_exporter
    chmod +x /usr/local/bin/suricata_exporter

Option B — Build from source (requires Go):

    go install github.com/corelight/suricata_exporter@latest

### 2.3  Create systemd service on so-oc

Create /etc/systemd/system/suricata-exporter.service:

    [Unit]
    Description=Suricata Prometheus Exporter
    After=suricata.service
    Requires=suricata.service

    [Service]
    Type=simple
    User=suricata
    ExecStart=/usr/local/bin/suricata_exporter \
        --suricata.socket-path=/var/run/suricata.socket \
        --web.listen-address=0.0.0.0:9917
    Restart=on-failure
    RestartSec=5

    [Install]
    WantedBy=multi-user.target

Enable and start:

    sudo systemctl daemon-reload
    sudo systemctl enable --now suricata-exporter.service

    # Verify locally
    curl -s http://localhost:9917/metrics | grep suricata_up

### 2.4  Firewall: allow Netdata to scrape port 9917

On OPNSense (or on so-oc's local firewall), allow TCP 9917 inbound from prod3's VLAN-3 IP
(prod3 net1 on VLAN 3 — check its IP with "ip addr show" for the VLAN-3 interface).

On so-oc with ufw:

    sudo ufw allow from PROD3_VLAN3_IP to any port 9917 proto tcp

### 2.5  Update prometheus.conf with so-oc's actual IP

Edit netdata/go.d/prometheus.conf and replace:
    REPLACE_WITH_SO_OC_VLAN3_IP
with so-oc's actual VLAN-3 IP address, then redeploy to /etc/netdata/go.d/prometheus.conf
and restart netdata:

    systemctl --user restart netdata.service

---

## Verification

After deployment, in Netdata UI (https://netdata.prod3.cktom.cyou):

1. Navigate to Metrics > Applications
2. Look for charts prefixed opnsense_ids_* and suricata_detect_*
3. Key metrics to confirm:
     opnsense_ids_alert_total     — OPNSense IPS alert count (cumulative)
     suricata_detect_alerts_total — Security Onion IDS alert count
     suricata_capture_kernel_drops_total — drops (should be near 0)
     suricata_decoder_packets_total — throughput counter

---

## Troubleshooting

### opnsense-exporter not scraping

    podman logs opnsense-exporter
    # Common issues:
    # - "connection refused" → OPNSense unreachable; check firewall rules
    # - "401 Unauthorized"  → wrong API key/secret
    # - "certificate verify" → add --opnsense.insecure=true (already set in quadlet)

### suricata_exporter connection refused

    # On so-oc:
    systemctl status suricata-exporter
    # Check socket exists:
    ls -la /var/run/suricata.socket
    # If missing, Suricata unix-command is disabled or Suricata isn't running

### Netdata not showing metrics

    # On prod3:
    curl -s http://127.0.0.1:19999/api/v1/charts | grep -o '"suricata[^"]*"\|"opnsense[^"]*"'
    # If empty, check:
    docker exec netdata cat /etc/netdata/go.d/prometheus.conf
    docker exec netdata netdatacli dumpconfig | grep prometheus
