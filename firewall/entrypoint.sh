#!/bin/bash
set -euo pipefail
echo "[vyos-lab-fw] Starting firewall container..."
/usr/sbin/sshd &
/opt/setup-rules.sh
echo "[vyos-lab-fw] Ready — nftables policy active, SSH on port 22"
exec tail -f /dev/null
