.PHONY: build pull deploy destroy logs clean inspect

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

# Build custom images then deploy the full lab
deploy: build
	mkdir -p logs/suricata
	./scripts/clab deploy -t topology.clab.yml

# Tear down the lab cleanly
destroy:
	./scripts/clab destroy -t topology.clab.yml

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
