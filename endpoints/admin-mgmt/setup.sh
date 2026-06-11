#!/bin/sh
# Admin jump host — authorized admin zone
# This host is the ONLY zone permitted to SSH into all zones (per VyOS policy)
echo "Admin management node ready at 10.10.40.10"
echo "Permitted to SSH: DMZ (10.10.10.x), Internal (10.10.20.x), Data (10.10.30.x)"
