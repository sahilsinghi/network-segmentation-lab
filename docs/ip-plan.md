# IP Address Plan

## Zone Overview

| Zone | Subnet | VyOS Interface | Purpose |
|------|--------|---------------|---------|
| DMZ | 10.10.10.0/24 | eth1 | Public-facing services + attacker |
| Internal | 10.10.20.0/24 | eth2 | Workstation simulation |
| Data | 10.10.30.0/24 | eth3 | Database tier |
| Management | 10.10.40.0/24 | eth4 | Admin jump host |
| Containerlab Mgmt | 172.20.20.0/24 | eth0 | Out-of-band container management |

## Host Assignments

### DMZ Zone — 10.10.10.0/24
| Host | IP | Role | Image |
|------|----|------|-------|
| VyOS gateway | 10.10.10.1 | L3 router/firewall | vyos/vyos:sagitta |
| nginx-dmz | 10.10.10.10 | nginx web server | nginx:1.25-alpine |
| kali | 10.10.10.20 | Attacker (Kali ARM64) | kalilinux/kali-rolling |

### Internal Zone — 10.10.20.0/24
| Host | IP | Role | Image |
|------|----|------|-------|
| VyOS gateway | 10.10.20.1 | L3 router/firewall | vyos/vyos:sagitta |
| workstation | 10.10.20.10 | Ubuntu workstation + SMB | ubuntu:22.04 |

### Data Zone — 10.10.30.0/24
| Host | IP | Role | Image |
|------|----|------|-------|
| VyOS gateway | 10.10.30.1 | L3 router/firewall | vyos/vyos:sagitta |
| postgres-db | 10.10.30.10 | PostgreSQL 15 | postgres:15-alpine |

### Management Zone — 10.10.40.0/24
| Host | IP | Role | Image |
|------|----|------|-------|
| VyOS gateway | 10.10.40.1 | L3 router/firewall | vyos/vyos:sagitta |
| admin-mgmt | 10.10.40.10 | Admin jump host | ubuntu:22.04 |

### Detection Plane (no zone IP — passive monitoring)
| Host | IP | Role | Image |
|------|----|------|-------|
| suricata | 172.20.20.x (mgmt) | IDS sidecar | jasonish/suricata:7.0 |
| filebeat | 172.20.20.x (mgmt) | Log shipper | elastic/filebeat:8.11.3 |

## Default Routes (per zone)
All endpoints use the VyOS interface as their default gateway.  
Suricata and Filebeat have no zone default route — passive-only.
