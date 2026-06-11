# Cross-Portfolio Bridge — Network Lab + SOC Lab

## The Unified Detection Narrative

This document explains how the Multi-Zone Network Segmentation Lab connects with
[SOC Detection Lab](https://github.com/sahilsinghi/soc-detection-lab) to create a single,
cohesive detection environment.

## Two Labs, One SIEM

```
┌─────────────────────────────────────────────────────────────────┐
│                    WAZUH OPENSEARCH DASHBOARD                    │
│                                                                  │
│   HOST TELEMETRY (SOC Lab)        NETWORK TELEMETRY (This Lab)  │
│   ─────────────────────────       ────────────────────────────  │
│   Sysmon: process creation        Suricata: EVE JSON alerts      │
│   Sysmon: registry modification   Suricata: network flows        │
│   Sysmon: network connections     Suricata: protocol anomalies   │
│   Wazuh agent: file integrity     Filebeat: suricata module      │
│   Atomic Red Team validation      Custom MITRE-tagged rules      │
└─────────────────────────────────────────────────────────────────┘
```

## How the Data Sources Complement Each Other

| Attack Stage | SOC Lab Catches | Network Lab Catches |
|-------------|----------------|---------------------|
| Reconnaissance | Sysmon: port scanner process creation | Suricata SID 9001004: SYN sweep alert |
| Lateral movement via SMB | Sysmon: SMB client process, LSASS access | Suricata SID 9001001: SMB enum cross-zone |
| Credential brute force | Sysmon: failed login Event ID 4625 | Suricata SID 9001011: SSH threshold |
| Reverse shell execution | Sysmon: Event ID 1 — suspicious cmd | Suricata SID 9001009: /dev/tcp/ in stream |
| DNS exfiltration | Sysmon: Event ID 22 — DNS query | Suricata SID 9001007: long subdomain |
| ICMP covert channel | (host-side: no natural Sysmon hook) | Suricata SID 9001012: oversized ICMP |

**Key insight:** ICMP covert channels are nearly invisible at the host level — Sysmon has no
ICMP event. This is exactly the gap that the Network Lab fills: network-layer visibility
catches what host telemetry misses.

## Sample Wazuh Correlation Queries

Run these in Wazuh's OpenSearch Dashboards (Discover view):

### Find all alerts from both labs in the last hour
```json
{
  "query": {
    "bool": {
      "must": [
        { "range": { "@timestamp": { "gte": "now-1h" } } }
      ],
      "should": [
        { "match": { "agent.name": "soc-detection-lab-*" } },
        { "match": { "data.log_type": "suricata" } }
      ],
      "minimum_should_match": 1
    }
  },
  "sort": [{ "@timestamp": { "order": "desc" } }]
}
```

### Correlate by source IP (same attacker in both telemetry streams)
```json
{
  "query": {
    "bool": {
      "must": [
        { "term": { "data.src_ip": "10.10.10.20" } },
        { "range": { "@timestamp": { "gte": "now-30m" } } }
      ]
    }
  }
}
```

### Find Suricata + Sysmon events within 60 seconds of each other
```
# In Wazuh Dashboards — use the Timeline/Correlations feature:
# index: wazuh-alerts-*
# filter: rule.groups: "suricata" OR rule.groups: "sysmon"
# group by: data.srcip, @timestamp (60s window)
```

## Interview Talking Points

**"How do your labs connect?"**
> Both labs ship events to the same Wazuh manager. The SOC Lab uses Wazuh agents on Windows
> VMs to collect Sysmon telemetry — host-side TTPs like process creation and file access.
> The Network Lab uses Suricata with AF-PACKET capture on zone bridges to collect network-side
> TTPs like lateral movement attempts, DNS tunneling, and ICMP covert channels. In Wazuh's
> OpenSearch dashboard, I can correlate events from both sources by source IP and timestamp to
> reconstruct the full kill chain from initial recon through exfiltration.

**"What does the Network Lab catch that the SOC Lab misses?"**
> Three specific gaps: ICMP covert channels (Sysmon has no ICMP event), DNS tunneling from
> isolated zones (the Data zone has no agent, only Suricata sees it), and firewall bypass
> attempts that Sysmon never sees because the packet is dropped before reaching the host.

**"Why unified detection over separate SIEMs?"**
> SOC teams don't benefit from alert fragmentation. A kill chain that crosses host and network
> boundaries — which most real APT campaigns do — is only fully visible when both telemetry
> streams are in one query context. Separate SIEMs mean analysts context-switch between tools
> and miss the correlation window. My architecture proves this with a working demo.
