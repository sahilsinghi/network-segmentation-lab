# Threat Model — MITRE ATT&CK Mapping

## Scope
This document maps every control in the Multi-Zone Network Segmentation Lab to a specific
MITRE ATT&CK technique. Each row shows: the attacker TTP, how it manifests in the lab,
which control detects or blocks it, and the residual risk if the control fails.

---

## Control-to-TTP Mapping

### VyOS Firewall Controls

| VyOS Rule | MITRE Technique ID | Technique Name | What It Blocks | Residual Risk |
|-----------|-------------------|----------------|----------------|---------------|
| DMZ-TO-INTERNAL (drop non-HTTP) | T1021.002 | Remote Services: SMB/Windows Admin Shares | SMB lateral movement from compromised web server | Suricata SID 9001001 catches if traffic bypasses |
| DMZ-TO-INTERNAL (drop non-HTTP) | T1021.004 | Remote Services: SSH | SSH pivoting from DMZ | Suricata SID 9001003 catches cross-zone SSH |
| DMZ-TO-DATA (deny) | T1005 | Data from Local System | Direct database access from DMZ | Suricata PV-1 alerts on attempt |
| DMZ-TO-MGMT (deny) | T1078 | Valid Accounts | Admin credential stuffing from DMZ | Suricata PV-2 alerts on attempt |
| DATA-OUTBOUND (deny all init) | T1048 | Exfiltration Over Alternative Protocol | Any data exfil from database tier | DNS/ICMP covert channels bypass firewall — Suricata catches those |
| MGMT-TO-ALL SSH-only | T1021.001 | Remote Desktop Protocol | RDP lateral movement via jump host | Suricata SID 9002005 catches RDP attempts |
| INTERNAL-TO-DATA (PostgreSQL only) | T1190 | Exploit Public-Facing Application | DB service enumeration from Internal | Suricata SID 9001004 catches port scans |

### Suricata IDS Signatures

| Suricata SID | MITRE Technique ID | Technique Name | Detection Logic | True Positive Rate |
|--------------|-------------------|----------------|-----------------|-------------------|
| 9001001 | T1021.002 | SMB Lateral Movement | FF-SMB header on port 445 from DMZ | High — specific content match |
| 9001002 | T1021.002 | NetBIOS/SMB | TCP 139 from DMZ | High |
| 9001003 | T1021.004 | SSH from Data Zone | SYN to port 22 from DATA_NET | High — policy violation by definition |
| 9001004 | T1046 | Network Service Discovery | SYN sweep threshold 20 pkts/5s | Medium — may miss slow scans |
| 9001005 | T1046 | Nmap version probe | "Nmap" string in stream | High |
| 9001006 | T1558 | Kerberos ticket abuse | Kerberos AS-REQ from DMZ | Medium — depends on Kerberos traffic |
| 9001007 | T1048.003 | DNS tunneling | PCRE 50+ char subdomain label | High — dnscat2/iodine use long labels |
| 9001008 | T1048.003 | dnscat2 beacon | DNS frequency threshold | Medium — depends on timing |
| 9001009 | T1059.004 | Bash reverse shell | /dev/tcp/ string in stream | High — specific to bash reverse shells |
| 9001010 | T1059.006 | Python reverse shell | socket.connect() in stream | Medium — many legitimate uses |
| 9001011 | T1110.001 | SSH brute force | SSH SYN threshold 5/30s | High |
| 9001012 | T1095 | ICMP covert channel | ICMP payload > 512 bytes | High — >99% of legit pings are <128 bytes |
| 9001013 | T1095 | ICMP flood/covert | ICMP flood threshold | Medium — aggressive scan could FP |
| 9001014 | T1021.002 | Impacket SMBExec | PSEXESVC string | High — very specific indicator |
| 9001015 | T1021.002 | SMB admin share access | ADMIN$/C$ SMB tree connect | High |

### Policy Violation Rules (belt-and-suspenders)

| Suricata SID | MITRE Technique | What It Catches |
|--------------|----------------|-----------------|
| 9002001 | T1005 | DMZ direct access to Data zone |
| 9002002 | T1021 | DMZ to Management zone |
| 9002003 | T1021 | Telnet (legacy protocol) anywhere |
| 9002004 | T1048 | FTP from internal zones |
| 9002005 | T1021.001 | RDP from DMZ |
| 9002006 | T1071.004 | DNS on non-standard port |
| 9002007 | T1071.001 | HTTP beaconing pattern |
| 9002008 | T1048 | Data zone outbound connection |
| 9002009 | T1021.006 | WinRM cross-zone |
| 9002010 | T1005 | Direct PostgreSQL from DMZ |

---

## Kill Chain Coverage

### Example Kill Chain: Compromised DMZ → Data Exfiltration

| Stage | ATT&CK Tactic | Technique | Control | Detection |
|-------|--------------|-----------|---------|-----------|
| 1. Initial access | Initial Access | T1190 Exploit Public App | Network segmentation isolates DMZ | Suricata T1046 on recon |
| 2. Reconnaissance | Discovery | T1046 Network Service Scan | VyOS drops cross-zone probes | Suricata SID 9001004, 9001005 |
| 3. Lateral movement | Lateral Movement | T1021.002 SMB | VyOS DMZ-TO-INTERNAL blocks SMB | Suricata SID 9001001 (even if firewall catches it) |
| 4. Credential access | Credential Access | T1110.001 Brute force | VyOS drops SSH from DMZ | Suricata SID 9001011 |
| 5. Collection | Collection | T1005 Data from local system | DATA zone has no outbound route | Suricata SID 9002008 |
| 6. Exfiltration | Exfiltration | T1048.003 DNS tunneling | VyOS allows DNS (firewall gap) | Suricata SID 9001007, 9001008 — this is the detection point |
| 7. C2 beacon | Command & Control | T1095 ICMP covert | VyOS allows ICMP (firewall gap) | Suricata SID 9001012, 9001013 |

---

## Residual Risks and v2 Hardening

| Risk | Current Gap | v2 Mitigation |
|------|-------------|---------------|
| Slow/stealthy port scan | SID 9001004 threshold misses sub-threshold scans | Add Zeek conn.log behavioral analytics |
| Encrypted C2 over HTTPS | Suricata content match misses TLS payload | Add JA3/JA3S TLS fingerprinting rules |
| DNS exfil via legitimate resolver | If DNS traffic routes through corporate resolver | Add DNS allowlist; block direct DNS from non-DMZ |
| ICMP allowed by default | Covert channel uses legitimate ICMP path | Add VyOS ICMP rate-limit rule; switch to IPS mode for ICMP |
| Lateral movement inside zone | No intra-zone segmentation | Add eBPF/Tetragon for host-side network policy |
| Supply chain via Management zone | Admin host is highly privileged | Harden with PAM + MFA + session recording |
