#!/bin/bash
set -euo pipefail
echo "[vyos-lab-fw] Starting firewall container..."
/usr/sbin/sshd &

# Containerlab attaches eth1-4 after the container starts; wait for them.
for iface in eth1 eth2 eth3 eth4; do
    until ip link show "$iface" &>/dev/null; do sleep 0.5; done
done

/opt/setup-rules.sh
echo "[vyos-lab-fw] Ready — nftables policy active, SSH on port 22"
exec tail -f /dev/null
