# VyOS Policy Matrix — Quick Reference

See `docs/firewall-policy.md` for the full matrix with verification commands.

## Summary

```
DMZ (10.10.10.0/24) ──► Internal (10.10.20.0/24)  :  TCP 80,443 ALLOW | all else DROP
DMZ (10.10.10.0/24) ──► Data (10.10.30.0/24)       :  ALL DROP
DMZ (10.10.10.0/24) ──► Management (10.10.40.0/24)  :  ALL DROP
Internal             ──► Data                        :  TCP 5432 ALLOW | all else DROP
Internal             ──► Management                  :  ALL DROP
Data                 ──► Any                         :  ALL DROP (no outbound init)
Management           ──► All zones                   :  TCP 22 ALLOW | all else DROP
```

## Inspect Firewall Rules Inside Container

The lab firewall runs Alpine Linux + nftables (not VyOS CLI — see note below).
The policy in `vyos/bootstrap-config.boot` documents the equivalent VyOS syntax
for resume/portfolio purposes. The running enforcement is in `firewall/setup-rules.sh`.

```bash
docker exec -it clab-network-seg-lab-vyos bash

# Reload nftables policy without restarting container
/opt/setup-rules.sh

# Show current ruleset
nft list ruleset

# Show packet/byte counters per rule
nft list table ip filter

# Show NAT table
nft list table ip nat
```

## Common Debug Commands

```bash
# Show interfaces and IP assignments
docker exec clab-network-seg-lab-vyos ip addr show

# Watch forwarded packets (live — Ctrl+C to stop)
docker exec clab-network-seg-lab-vyos nft monitor

# Show conntrack table (active sessions)
docker exec clab-network-seg-lab-vyos cat /proc/net/nf_conntrack | head -20

# Verify route table
docker exec clab-network-seg-lab-vyos ip route show
```

> **Note on VyOS CLI syntax in bootstrap-config.boot:** The VyOS configuration
> file documents this lab's policy in real VyOS 1.4 syntax — useful for showing
> in interviews and for migrating to a real VyOS deployment. The lab runs
> Alpine+nftables because the VyOS ARM64 image is not available on Docker Hub.
> The nftables ruleset in `firewall/setup-rules.sh` is the functional equivalent.
