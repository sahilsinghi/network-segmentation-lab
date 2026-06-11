#!/bin/bash
# Attack Simulation 01 — External Port Scan
# MITRE ATT&CK: T1046 — Network Service Discovery
# Attacker: Kali (10.10.10.20) in DMZ
# Target:   Internal zone (10.10.20.0/24)
# Expected VyOS action:  TCP SYN packets forwarded (HTTP only allowed); other ports dropped
# Expected Suricata SID: 9001004 (SYN sweep threshold), 9001005 (nmap probe)
# Expected Wazuh alert:  rule group "suricata" — network-scan classtype

set -euo pipefail

TARGET_RANGE="10.10.20.0/24"
WORKSTATION="10.10.20.10"
LOG_DIR="/tmp/attack-logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "============================================================"
echo "  ATTACK 01 — Network Service Discovery (T1046)"
echo "  Attacker: $(hostname) | Target: $TARGET_RANGE"
echo "  Time: $(date)"
echo "============================================================"

# Phase 1: Host discovery ping sweep
echo "[+] Phase 1: ICMP host discovery"
nmap -sn "$TARGET_RANGE" -oN "$LOG_DIR/01a-ping-sweep-$TIMESTAMP.txt" 2>&1
echo "[*] Ping sweep complete — check Suricata for T1046 alerts"

sleep 2

# Phase 2: SYN scan on workstation — top 1000 ports
echo "[+] Phase 2: SYN scan top-1000 ports on $WORKSTATION"
nmap -sS -T4 --top-ports 1000 "$WORKSTATION" \
     -oN "$LOG_DIR/01b-syn-scan-$TIMESTAMP.txt" \
     -oX "$LOG_DIR/01b-syn-scan-$TIMESTAMP.xml" 2>&1

# Phase 3: Service version detection
echo "[+] Phase 3: Service version detection on $WORKSTATION"
nmap -sV -sC -p 22,80,139,443,445 "$WORKSTATION" \
     -oN "$LOG_DIR/01c-version-scan-$TIMESTAMP.txt" 2>&1

echo ""
echo "[RESULTS] Output saved to $LOG_DIR/"
echo "[EXPECTED DETECTIONS]"
echo "  Suricata SID 9001004 — SYN sweep threshold exceeded"
echo "  Suricata SID 9001005 — Nmap service version probe string"
echo "  EVE JSON event_type: alert, classtype: network-scan"
echo "  Wazuh dashboard: Security Alerts > network-scan"
echo "============================================================"
