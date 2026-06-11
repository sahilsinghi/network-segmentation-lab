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

## Apply Config Inside VyOS Container

```bash
docker exec -it clab-network-seg-lab-vyos bash
vbash /opt/vyatta/sbin/vyatta-cfg-cmd-wrapper begin
vbash /opt/vyatta/sbin/vyatta-cfg-cmd-wrapper load /opt/vyatta/etc/config/config.boot
vbash /opt/vyatta/sbin/vyatta-cfg-cmd-wrapper commit
vbash /opt/vyatta/sbin/vyatta-cfg-cmd-wrapper save
```

## Common VyOS Debug Commands

```bash
# Show active firewall counters
show firewall ipv4 name DMZ-TO-INTERNAL statistics

# Show conntrack table
show system conntrack-table

# Tail firewall log
sudo journalctl -f -u vyos-router

# Show interfaces with IPs
show interfaces
```
