#!/bin/sh
# Workstation Internal — post-start setup
# Creates decoy files and starts services
echo "Workstation user data" > /srv/share/workstation-data.txt
echo "Setting up internal workstation..."
service smbd start 2>/dev/null || true
/usr/sbin/sshd 2>/dev/null || true
echo "Internal workstation ready at 10.10.20.10"
