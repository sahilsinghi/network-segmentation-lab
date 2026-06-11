FROM alpine:3.19
RUN apk add --no-cache \
    nftables \
    iptables \
    ip6tables \
    iproute2 \
    iputils \
    bash \
    openssh \
    curl \
    tcpdump \
    && mkdir /run/sshd \
    && echo 'root:labpassword123' | chpasswd \
    && ssh-keygen -A \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

COPY setup-rules.sh /opt/setup-rules.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /opt/setup-rules.sh /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
