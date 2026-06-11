FROM postgres:15-alpine
RUN apk add --no-cache openssh openssh-server iputils iproute2 && \
    mkdir /run/sshd && \
    echo 'root:labpassword' | chpasswd && \
    ssh-keygen -A && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

ENV POSTGRES_DB=labdb \
    POSTGRES_USER=labuser \
    POSTGRES_PASSWORD=labpassword

# Seed schema — creates a table with mock PII for data exfil scenarios
COPY init.sql /docker-entrypoint-initdb.d/01-init.sql

EXPOSE 5432 22
CMD ["/bin/sh", "-c", "/usr/sbin/sshd & docker-entrypoint.sh postgres"]
