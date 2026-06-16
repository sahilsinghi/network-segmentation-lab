.PHONY: build pull deploy destroy logs clean inspect bridges tap-mirrors

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

# Wire up TC ingress mirrors so Suricata sees all bridge traffic (run after deploy)
# Linux bridges do unicast forwarding once MACs are learned, bypassing the IDS tap.
# TC mirrors copy every frame entering each data port to the corresponding ids-* tap.
tap-mirrors:
	docker run --rm --privileged --network host alpine:latest sh -c "\
	  apk add -q iproute2 2>/dev/null; TC=/sbin/tc; \
	  mirror() { \$$TC qdisc del dev \$$1 ingress 2>/dev/null||true; \$$TC qdisc add dev \$$1 handle ffff: ingress; \$$TC filter add dev \$$1 parent ffff: matchall action mirred egress mirror dev \$$2; echo \"  [+] \$$1 → \$$2\"; }; \
	  echo '[br-dmz]';      mirror fw-dmz ids-dmz; mirror ep-nginx ids-dmz; mirror ep-kali ids-dmz; \
	  echo '[br-internal]'; mirror fw-int ids-int;  mirror ep-ws ids-int; \
	  echo '[br-data]';     mirror fw-data ids-data; mirror ep-pg ids-data; \
	  echo '[br-mgmt]';     mirror fw-mgmt ids-mgmt; mirror ep-admin ids-mgmt; \
	  echo '[+] All IDS tap mirrors active'"

# Build custom images then deploy the full lab
deploy: build bridges
	mkdir -p logs/suricata
	./scripts/clab deploy -t topology.clab.yml
	$(MAKE) tap-mirrors

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
