#!/bin/bash
# Attack Simulation 06 — ICMP Covert Channel
# MITRE ATT&CK: T1095 — Non-Application Layer Protocol
# Attacker: Kali (10.10.10.20) in DMZ
# Target:   Internal zone (10.10.20.10)
# Expected VyOS action:  ICMP allowed through (ICMP not in default-deny for this lab)
#                        — Suricata is the detection layer here
# Expected Suricata SID: 9001012 (oversized ICMP >512 bytes), 9001013 (ICMP flood)
# Expected Wazuh alert:  rule group "suricata" — policy-violation classtype
#
# NOTE: This simulation demonstrates why SIEM correlation matters.
#       VyOS does NOT block ICMP by default (needed for diagnostics).
#       Suricata catches the covert channel pattern that the firewall misses.
#       This is the "two layers catch different things" demo point.

set -euo pipefail

TARGET="10.10.20.10"
KALI_IP="10.10.10.20"
LOG_DIR="/tmp/attack-logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "============================================================"
echo "  ATTACK 06 — ICMP Covert Channel (T1095)"
echo "  Attacker: $KALI_IP | Target: $TARGET"
echo "  Time: $(date)"
echo "============================================================"

# Phase 1: Normal ping (baseline — should NOT trigger Suricata)
echo "[+] Phase 1: Normal ICMP ping (baseline — no alert expected)"
ping -c 4 -s 56 "$TARGET" 2>&1 | tee "$LOG_DIR/06a-normal-ping-$TIMESTAMP.txt"
echo "[*] Normal ping complete — no Suricata alert expected"

sleep 2

# Phase 2: Oversized ICMP — encodes "data" in large payload (triggers SID 9001012)
echo "[+] Phase 2: Oversized ICMP ping (600 byte payload — triggers SID 9001012)"
ping -c 5 -s 600 "$TARGET" 2>&1 | tee "$LOG_DIR/06b-oversized-ping-$TIMESTAMP.txt"
echo "[*] 600-byte ICMP sent — Suricata should alert on dsize:>512"

sleep 2

# Phase 3: ICMP flood (high rate — triggers SID 9001013 threshold)
echo "[+] Phase 3: ICMP flood (30+ packets in 5 seconds — triggers SID 9001013)"
ping -c 40 -i 0.1 -s 64 "$TARGET" \
    2>&1 | tee "$LOG_DIR/06c-icmp-flood-$TIMESTAMP.txt" || \
    echo "[NOTE] Flood may be rate-limited by container kernel"
echo "[*] ICMP flood complete — threshold-based rule should fire"

sleep 2

# Phase 4: icmptunnel-style large payload (simulates data encoding in ICMP)
echo "[+] Phase 4: ICMP covert channel payload simulation"
PAYLOAD=$(python3 -c "import base64; print(base64.b64encode(b'EXFIL:admin:password123').decode())")
# Pad to >512 bytes
PADDED_PAYLOAD=$(python3 -c "
import struct, os
header = b'COVERT:SESSION_01:'
data = b'$PAYLOAD'
pad = b'A' * (520 - len(header) - len(data))
print(len(header + data + pad), 'bytes crafted')
")
echo "[*] $PADDED_PAYLOAD"
ping -c 3 -s 520 -p "$(echo -n 'COVERT_CHANNEL' | xxd -p | head -c 16)" \
    "$TARGET" 2>&1 | tee "$LOG_DIR/06d-covert-payload-$TIMESTAMP.txt" || \
    echo "[NOTE] Pattern ping may not be supported — oversized ping still fires rule"

echo ""
echo "[RESULTS] Output saved to $LOG_DIR/"
echo "[EXPECTED DETECTIONS]"
echo "  VyOS:     NOT blocked — ICMP allowed for diagnostics (firewall gap)"
echo "  Suricata SID 9001012 — oversized ICMP dsize > 512"
echo "  Suricata SID 9001013 — ICMP flood threshold 30+ pkts in 5s"
echo "  EVE JSON event_type: alert, classtype: policy-violation"
echo "  Wazuh dashboard: Security Alerts > policy-violation"
echo ""
echo "INTERVIEW POINT: This simulation proves why layered defense matters."
echo "VyOS (L3 firewall) misses covert ICMP — Suricata (L7 IDS) catches it."
echo "Wazuh correlates both layers under one dashboard."
echo "============================================================"
