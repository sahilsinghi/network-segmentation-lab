# Suricata IDS — Configuration Guide

## Setup

Suricata runs as a Containerlab node with AF-PACKET taps on all four zone bridges.
It operates in **IDS mode** (alert-only, no inline drops).

### First-time ET Open rules download

```bash
# Inside suricata container
docker exec -it clab-network-seg-lab-suricata bash
suricata-update
suricata-update list-sources
```

### Reload rules without restart

```bash
docker exec clab-network-seg-lab-suricata kill -USR2 1
```

## Custom Rules

| File | SID Range | Coverage |
|------|-----------|----------|
| `custom-rules/lateral-movement.rules` | 9001001–9001015 | T1021, T1046, T1048, T1059, T1095, T1110, T1558 |
| `custom-rules/policy-violations.rules` | 9002001–9002010 | Zone policy bypass detection |

## Viewing Alerts

```bash
# Live EVE JSON alert stream
docker exec clab-network-seg-lab-suricata \
    tail -f /var/log/suricata/eve.json | \
    python3 -m json.tool | grep -A5 '"event_type":"alert"'

# Fast log
docker exec clab-network-seg-lab-suricata \
    tail -f /var/log/suricata/fast.log

# Filter by custom rule SID range
docker exec clab-network-seg-lab-suricata \
    grep '"sid":9001' /var/log/suricata/eve.json | python3 -m json.tool
```

## IDS → IPS Migration (v2)

To switch to IPS mode on the DMZ interface only:
1. Change `inline: no` to `inline: yes` in `suricata.yaml`
2. In `topology.clab.yml`, change `copy-mode: ips` for `eth1` af-packet config
3. Add `drop` action to rules where you want active blocking
4. Redeploy: `containerlab redeploy -t topology.clab.yml`
