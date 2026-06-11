FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    openssh-server \
    samba \
    samba-client \
    cifs-utils \
    nmap \
    curl \
    wget \
    netcat-openbsd \
    iputils-ping \
    iproute2 \
    python3 \
    python3-pip \
    tcpdump \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir /run/sshd && \
    echo 'root:labpassword' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config

# Samba share (simulates Windows workstation SMB share)
RUN mkdir -p /srv/share && chmod 777 /srv/share && \
    echo "[share]\npath = /srv/share\nbrowseable = yes\nread only = no\nguest ok = yes" \
    >> /etc/samba/smb.conf

COPY setup.sh /opt/setup.sh
RUN chmod +x /opt/setup.sh

EXPOSE 22 139 445
CMD ["/bin/sh", "-c", "service smbd start && /usr/sbin/sshd -D"]
