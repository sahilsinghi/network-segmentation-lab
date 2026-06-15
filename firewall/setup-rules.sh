#!/bin/bash
# Firewall rules implementing the VyOS policy matrix via nftables.
# Policy documented in VyOS CLI syntax in: vyos/bootstrap-config.boot
# These rules are the functional equivalent running on Alpine Linux.
#
# Zone → Interface mapping:
#   eth1 = DMZ        10.10.10.0/24
#   eth2 = Internal   10.10.20.0/24
#   eth3 = Data       10.10.30.0/24
#   eth4 = Management 10.10.40.0/24

set -euo pipefail

# ── Enable IP forwarding ────────────────────────────────────────────────────
echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || true
sysctl -w net.ipv4.ip_forward=1 2>/dev/null || true

# ── Assign interface IPs (Containerlab may handle this, belt-and-suspenders) ─
ip addr show eth1 | grep -q "10.10.10.1" || ip addr add 10.10.10.1/24 dev eth1 2>/dev/null || true
ip addr show eth2 | grep -q "10.10.20.1" || ip addr add 10.10.20.1/24 dev eth2 2>/dev/null || true
ip addr show eth3 | grep -q "10.10.30.1" || ip addr add 10.10.30.1/24 dev eth3 2>/dev/null || true
ip addr show eth4 | grep -q "10.10.40.1" || ip addr add 10.10.40.1/24 dev eth4 2>/dev/null || true

ip link set eth1 up 2>/dev/null || true
ip link set eth2 up 2>/dev/null || true
ip link set eth3 up 2>/dev/null || true
ip link set eth4 up 2>/dev/null || true

# ── Load nftables ruleset ────────────────────────────────────────────────────
nft -f /dev/stdin << 'NFTABLES'
flush ruleset

# ── Address definitions ──────────────────────────────────────────────────────
define DMZ_NET      = 10.10.10.0/24
define INTERNAL_NET = 10.10.20.0/24
define DATA_NET     = 10.10.30.0/24
define MGMT_NET     = 10.10.40.0/24

table ip filter {

    # ── Base chain: forward all inter-zone traffic through here ───────────────
    chain FORWARD {
        type filter hook forward priority 0; policy drop;

        # Allow established / related (conntrack)
        ct state established,related accept
        ct state invalid drop

        # ── DMZ → Internal: HTTP/HTTPS only (T1021.002 detection surface) ─────
        iifname "eth1" oifname "eth2" tcp dport { 80, 443 } ct state new accept
        iifname "eth1" oifname "eth2" drop

        # ── DMZ → Data: DENY all ─────────────────────────────────────────────
        iifname "eth1" oifname "eth3" drop

        # ── DMZ → Management: DENY all ───────────────────────────────────────
        iifname "eth1" oifname "eth4" drop

        # ── Internal → Data: PostgreSQL only ─────────────────────────────────
        iifname "eth2" oifname "eth3" tcp dport 5432 ct state new accept
        iifname "eth2" oifname "eth3" drop

        # ── Internal → Management: DENY ──────────────────────────────────────
        iifname "eth2" oifname "eth4" drop

        # ── Data → anywhere: DENY all outbound-initiated ─────────────────────
        iifname "eth3" drop

        # ── Management → all zones: SSH only ─────────────────────────────────
        iifname "eth4" tcp dport 22 ct state new accept
        iifname "eth4" drop
    }

    # ── INPUT: allow SSH to firewall itself from Management zone only ─────────
    chain INPUT {
        type filter hook input priority 0; policy drop;
        ct state established,related accept
        iifname "lo" accept
        iifname "eth0" accept          # containerlab mgmt interface
        iifname "eth4" tcp dport 22 accept
        icmp type echo-request accept  # allow ping to firewall
    }

    chain OUTPUT {
        type filter hook output priority 0; policy accept;
    }
}

# ── NAT: masquerade DMZ to simulated internet via eth0 ───────────────────────
table ip nat {
    chain POSTROUTING {
        type nat hook postrouting priority 100; policy accept;
        oifname "eth0" ip saddr 10.10.0.0/16 masquerade
    }
}
NFTABLES

echo "[+] nftables rules loaded — firewall active"
echo "[+] Zone policy:"
echo "    DMZ(eth1)  → Internal(eth2): TCP 80,443 ONLY"
echo "    DMZ(eth1)  → Data(eth3):     DENY"
echo "    DMZ(eth1)  → Mgmt(eth4):     DENY"
echo "    Int(eth2)  → Data(eth3):     TCP 5432 ONLY"
echo "    Int(eth2)  → Mgmt(eth4):     DENY"
echo "    Data(eth3) → Any:            DENY (no outbound init)"
echo "    Mgmt(eth4) → All:            TCP 22 ONLY"
