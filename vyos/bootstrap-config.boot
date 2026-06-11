/* VyOS 1.4 (sagitta) — Lab Firewall Bootstrap Config
 * Lab-only credentials — do NOT use in production.
 * Admin: admin / labpassword123
 */

interfaces {
    ethernet eth0 {
        description "Containerlab Management (DHCP)"
        address dhcp
    }
    ethernet eth1 {
        address 10.10.10.1/24
        description "DMZ — 10.10.10.0/24"
    }
    ethernet eth2 {
        address 10.10.20.1/24
        description "Internal — 10.10.20.0/24"
    }
    ethernet eth3 {
        address 10.10.30.1/24
        description "Data — 10.10.30.0/24"
    }
    ethernet eth4 {
        address 10.10.40.1/24
        description "Management — 10.10.40.0/24"
    }
    loopback lo {
    }
}

/* ── Address groups ─────────────────────────────────────────────────────── */
firewall {
    group {
        network-group DMZ-NET {
            description "DMZ zone hosts"
            network 10.10.10.0/24
        }
        network-group INTERNAL-NET {
            description "Internal workstations"
            network 10.10.20.0/24
        }
        network-group DATA-NET {
            description "Database tier"
            network 10.10.30.0/24
        }
        network-group MGMT-NET {
            description "Admin jump hosts"
            network 10.10.40.0/24
        }
    }

    /* ── Stateful base rules (every policy starts here) ──────────────────── */
    ipv4 {

        /* DMZ → Internal: HTTP/HTTPS only (T1071.001 detection surface) */
        name DMZ-TO-INTERNAL {
            default-action drop
            description "DMZ to Internal — HTTP/HTTPS only"
            rule 5 {
                action accept
                description "Allow established/related"
                state {
                    established enable
                    related enable
                }
            }
            rule 10 {
                action drop
                description "Drop invalid"
                state {
                    invalid enable
                }
            }
            rule 100 {
                action accept
                description "HTTP — T1071.001 detection surface"
                destination {
                    port 80,443
                }
                protocol tcp
            }
        }

        /* Internal → Data: PostgreSQL only */
        name INTERNAL-TO-DATA {
            default-action drop
            description "Internal to Data — PostgreSQL port only"
            rule 5 {
                action accept
                state {
                    established enable
                    related enable
                }
            }
            rule 10 {
                action drop
                state {
                    invalid enable
                }
            }
            rule 100 {
                action accept
                description "PostgreSQL 5432"
                destination {
                    port 5432
                }
                protocol tcp
            }
        }

        /* Management → ALL: SSH only */
        name MGMT-TO-ALL {
            default-action drop
            description "Management to all zones — SSH only"
            rule 5 {
                action accept
                state {
                    established enable
                    related enable
                }
            }
            rule 10 {
                action drop
                state {
                    invalid enable
                }
            }
            rule 100 {
                action accept
                description "SSH from jump host"
                destination {
                    port 22
                }
                protocol tcp
            }
        }

        /* Data → anywhere: deny all outbound-initiated */
        name DATA-OUTBOUND {
            default-action drop
            description "Data zone — deny all outbound initiated traffic"
            rule 5 {
                action accept
                description "Allow return traffic for inbound-initiated sessions"
                state {
                    established enable
                    related enable
                }
            }
        }

        /* DMZ → Data: explicit deny (short-circuit before any allow) */
        name DMZ-TO-DATA {
            default-action drop
            description "DMZ to Data — always deny"
        }

        /* DMZ → Management: explicit deny */
        name DMZ-TO-MGMT {
            default-action drop
            description "DMZ to Management — always deny"
        }

        /* Internal → Management: deny */
        name INTERNAL-TO-MGMT {
            default-action drop
            description "Internal to Management — deny"
            rule 5 {
                action accept
                state {
                    established enable
                    related enable
                }
            }
        }

        /* Return traffic policy (applied outbound on all zone interfaces) */
        name RETURN-TRAFFIC {
            default-action drop
            description "Allow established return traffic outbound"
            rule 5 {
                action accept
                state {
                    established enable
                    related enable
                }
            }
            rule 10 {
                action drop
                state {
                    invalid enable
                }
            }
        }
    }
}

/* ── Apply policies per interface ────────────────────────────────────────── */
interfaces {
    ethernet eth1 {
        firewall {
            in {
                /* Traffic coming IN from DMZ: selectively allow to each dest */
                name DMZ-TO-INTERNAL
            }
            out {
                name RETURN-TRAFFIC
            }
        }
    }
    ethernet eth2 {
        firewall {
            in {
                name INTERNAL-TO-DATA
            }
            out {
                name RETURN-TRAFFIC
            }
        }
    }
    ethernet eth3 {
        firewall {
            in {
                name DATA-OUTBOUND
            }
            out {
                name RETURN-TRAFFIC
            }
        }
    }
    ethernet eth4 {
        firewall {
            in {
                name MGMT-TO-ALL
            }
            out {
                name RETURN-TRAFFIC
            }
        }
    }
}

/* ── NAT (lab internet simulation) ──────────────────────────────────────── */
nat {
    source {
        rule 100 {
            description "Masquerade DMZ to internet (simulated)"
            outbound-interface name eth0
            source {
                address 10.10.10.0/24
            }
            translation {
                address masquerade
            }
        }
    }
}

/* ── System ──────────────────────────────────────────────────────────────── */
system {
    config-management {
        commit-revisions 100
    }
    conntrack {
        modules {
            ftp
            sip
            tftp
        }
        table-size 32768
    }
    domain-name lab.local
    host-name vyos-lab-fw
    login {
        user admin {
            authentication {
                plaintext-password "labpassword123"
            }
            level admin
        }
    }
    syslog {
        global {
            facility all {
                level info
            }
            facility protocols {
                level debug
            }
        }
    }
    time-zone UTC
}

/* ── SSH service (for admin access and Containerlab node config) ─────────── */
service {
    ssh {
        disable-host-validation
        port 22
    }
}
