FROM nginx:1.25-alpine
RUN apk add --no-cache openssh-server nmap curl iputils-ping iproute2 && \
    mkdir /run/sshd && \
    echo 'root:labpassword' | chpasswd && \
    ssh-keygen -A && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
COPY default.conf /etc/nginx/conf.d/default.conf
EXPOSE 80 443 22
CMD ["/bin/sh", "-c", "/usr/sbin/sshd && nginx -g 'daemon off;'"]
