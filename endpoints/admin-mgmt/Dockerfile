FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    openssh-server \
    openssh-client \
    nmap \
    curl \
    wget \
    iputils-ping \
    iproute2 \
    net-tools \
    python3 \
    netcat-openbsd \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir /run/sshd && \
    echo 'root:labpassword' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config

COPY setup.sh /opt/setup.sh
RUN chmod +x /opt/setup.sh

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
