# VyOS Firewall Policy Matrix

## Design Principles
- **Default-deny**: all inter-zone traffic is blocked unless explicitly permitted
- **Stateful inspection**: established/related sessions tracked by conntrack
- **Least-privilege**: each zone may only initiate the minimum required traffic
- **Explicit logging**: all drops logged for Wazuh correlation

## Policy Matrix

| Source Zone | Destination Zone | Permitted Traffic | VyOS Rule Name | Action |
|-------------|-----------------|-------------------|----------------|--------|
| DMZ (10.10.10.0/24) | Internal (10.10.20.0/24) | TCP 80, 443 (HTTP/HTTPS) | DMZ-TO-INTERNAL | ALLOW |
| DMZ (10.10.10.0/24) | Data (10.10.30.0/24) | **NONE** | DMZ-TO-DATA | DENY |
| DMZ (10.10.10.0/24) | Management (10.10.40.0/24) | **NONE** | DMZ-TO-MGMT | DENY |
| Internal (10.10.20.0/24) | Data (10.10.30.0/24) | TCP 5432 (PostgreSQL) | INTERNAL-TO-DATA | ALLOW |
| Internal (10.10.20.0/24) | Management (10.10.40.0/24) | **NONE** | INTERNAL-TO-MGMT | DENY |
| Internal (10.10.20.0/24) | DMZ (10.10.10.0/24) | Established/related only | RETURN-TRAFFIC | ALLOW |
| Data (10.10.30.0/24) | Any | **NONE** (no outbound init) | DATA-OUTBOUND | DENY |
| Management (10.10.40.0/24) | All zones | TCP 22 (SSH only) | MGMT-TO-ALL | ALLOW |
| Any | Any (catch-all) | **NONE** | default-action drop | DENY |

> Return traffic (established/related) is always permitted per stateful rule 5 in every policy chain.

## Interface-to-Policy Binding

| VyOS Interface | Zone | Inbound Policy | Outbound Policy |
|----------------|------|----------------|-----------------|
| eth1 | DMZ | DMZ-TO-INTERNAL | RETURN-TRAFFIC |
| eth2 | Internal | INTERNAL-TO-DATA | RETURN-TRAFFIC |
| eth3 | Data | DATA-OUTBOUND | RETURN-TRAFFIC |
| eth4 | Management | MGMT-TO-ALL | RETURN-TRAFFIC |

## Verification Commands

Run from inside Kali container (`docker exec -it clab-network-seg-lab-kali bash`):

```bash
# Verify allowed: DMZ → Internal HTTP
curl -m5 http://10.10.20.10/    # expect response or 404 (not timeout)

# Verify blocked: DMZ → Internal SSH
nc -w3 10.10.20.10 22           # expect timeout

# Verify blocked: DMZ → Data PostgreSQL
nc -w3 10.10.30.10 5432         # expect timeout

# Verify blocked: DMZ → Management SSH
nc -w3 10.10.40.10 22           # expect timeout

# From admin-mgmt (Management zone) — verify allowed
docker exec -it clab-network-seg-lab-admin-mgmt bash
ssh root@10.10.10.10            # DMZ → should succeed from mgmt
ssh root@10.10.20.10            # Internal → should succeed from mgmt
ssh root@10.10.30.10            # Data → should succeed from mgmt
```

## Firewall Log Location

```bash
# View VyOS firewall log (inside vyos container)
docker exec -it clab-network-seg-lab-vyos bash
show log firewall
```
