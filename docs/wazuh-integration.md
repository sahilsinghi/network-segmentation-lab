# Wazuh SIEM Integration

## Overview

Suricata IDS alerts from this lab are forwarded to the Wazuh SIEM manager (Project 06 — SOC Detection Lab) in real time. This creates a cross-portfolio detection pipeline:

```
Suricata (Docker) → EVE JSON → Wazuh Agent (macOS) → Wazuh Manager → Rule 86601
```

## Architecture

| Component | Location | Role |
|-----------|----------|------|
| Suricata 7.0 | `clab-network-seg-lab-suricata` container | Passive IDS on all zone bridges |
| EVE JSON log | `logs/suricata/eve.json` (bind-mounted to Mac host) | Structured alert output |
| Wazuh Agent 4.13.1 | macOS host (Sahils-MacBook-Pro.local, Agent ID 001) | Log collector → Manager |
| Wazuh Manager 4.13.1 | Ubuntu VM at `192.168.64.40` | Decoder + rule engine |

## Why This Approach

The Wazuh Manager (Ubuntu VM) does not expose port 9200 (OpenSearch) or 5044 (Logstash) to the host network — both are bound to localhost inside the VM. The Containerlab Filebeat container (`clab-network-seg-lab-filebeat`) therefore cannot reach the manager directly.

The macOS Wazuh agent solves this cleanly: Suricata's EVE JSON is bind-mounted to the Mac host filesystem at `logs/suricata/eve.json`. The agent's `logcollector` monitors this file natively and forwards events over port 1514 (the standard Wazuh agent protocol, which is open).

## Configuration

The `<localfile>` block added to `/Library/Ossec/etc/ossec.conf` on the Mac:

```xml
<!-- Suricata EVE JSON — Network Segmentation Lab (Project 04) -->
<localfile>
  <log_format>json</log_format>
  <location>/Users/sahilsinghi/Desktop/network-segmentation-lab/logs/suricata/eve.json</location>
  <label key="lab">network-seg-lab</label>
</localfile>
```

## Validated Alert Flow

**Trigger:** nmap SYN scan from Kali (10.10.10.20 / DMZ) toward Internal zone (10.10.20.10)

**Suricata fired:** `POLICY-VIOLATION RDP from DMZ T1021.001` (sid:9002005)

**Wazuh alert generated:**
```
Rule: 86601 (level 3) -> 'Suricata: Alert - POLICY-VIOLATION RDP from DMZ T1021.001'
Agent: Sahils-MacBook-Pro.local
Source: /Users/sahilsinghi/Desktop/network-segmentation-lab/logs/suricata/eve.json
MITRE: T1021.001 — Remote Desktop Protocol, Lateral Movement
```

**Verified in:** `/var/ossec/logs/alerts/alerts.log` on the Wazuh Manager VM.

## Filebeat Container (Production Reference)

The `filebeat` node in `topology.clab.yml` and `filebeat/filebeat.yml` document the production-grade approach: Filebeat reads `eve.json` and ships directly to a Wazuh/OpenSearch cluster over port 9200 with mutual TLS. TLS certificates from the Wazuh manager are in `filebeat/certs/`.

In this single-host lab environment, the macOS Wazuh agent is used instead (see above). The Filebeat config remains as an architectural reference for deploying this lab against a production Wazuh cluster.
