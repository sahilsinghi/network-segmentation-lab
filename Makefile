.PHONY: build pull deploy destroy logs clean inspect bridges

CLAB_VERSION ?= 0.76.0

# Build all custom Docker images required by the topology
build:
	docker build -t lab-firewall:latest ./firewall/
	docker build -t lab-nginx-dmz:latest ./endpoints/nginx-dmz/
	docker build -t lab-workstation:latest ./endpoints/workstation-internal/
	docker build -t lab-postgres:latest ./endpoints/postgres-data/
	docker build -t lab-admin-mgmt:latest ./endpoints/admin-mgmt/

# Pull remote images (Kali is ~3 GB — run this before a timed demo)
pull:
	docker pull kalilinux/kali-rolling
	docker pull jasonish/suricata:7.0
	docker pull docker.elastic.co/beats/filebeat:8.11.3
	docker pull ghcr.io/srl-labs/clab:$(CLAB_VERSION)

# Pre-create zone Linux bridges in Docker Desktop's VM (Containerlab 0.56+ requires them to exist)
bridges:
	docker run --rm --privileged --network host alpine:latest sh -c "\
	  ip link add br-dmz type bridge 2>/dev/null || true; ip link set br-dmz up; \
	  ip link add br-internal type bridge 2>/dev/null || true; ip link set br-internal up; \
	  ip link add br-data type bridge 2>/dev/null || true; ip link set br-data up; \
	  ip link add br-mgmt type bridge 2>/dev/null || true; ip link set br-mgmt up; \
	  echo '[+] Bridges ready: br-dmz br-internal br-data br-mgmt'"

# Build custom images then deploy the full lab
deploy: build bridges
	mkdir -p logs/suricata
	./scripts/clab deploy -t topology.clab.yml

# Tear down the lab cleanly and remove zone bridges
destroy:
	./scripts/clab destroy -t topology.clab.yml || true
	docker run --rm --privileged --network host alpine:latest sh -c "\
	  ip link del br-dmz 2>/dev/null || true; \
	  ip link del br-internal 2>/dev/null || true; \
	  ip link del br-data 2>/dev/null || true; \
	  ip link del br-mgmt 2>/dev/null || true; \
	  echo '[+] Bridges removed'"

# Show running nodes and their management IPs
inspect:
	./scripts/clab inspect -t topology.clab.yml

# Tail Suricata fast.log for live alerts
logs:
	docker exec clab-network-seg-lab-suricata tail -f /var/log/suricata/fast.log

# Remove built custom images (run after destroy)
clean:
	docker rmi lab-firewall:latest lab-nginx-dmz:latest lab-workstation:latest \
	           lab-postgres:latest lab-admin-mgmt:latest 2>/dev/null || true
