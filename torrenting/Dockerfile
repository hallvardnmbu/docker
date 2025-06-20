FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl wget git vim htop build-essential sudo \
    openvpn iptables qbittorrent-nox iproute2 net-tools dnsutils \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -d /home -s /bin/bash playground && \
    echo "playground:lavik" | chpasswd && \
    usermod -aG sudo playground

RUN mkdir -p /etc/openvpn/nordvpn /home/downloads /home/config && \
    chown -R playground:playground /home/downloads /home/config

WORKDIR /home

COPY scripts/start-vpn.sh /usr/local/bin/start-vpn.sh
COPY scripts/killswitch.sh /usr/local/bin/killswitch.sh
RUN chmod +x /usr/local/bin/start-vpn.sh /usr/local/bin/killswitch.sh

USER playground
RUN echo 'export PS1="\[\033[01;32m\]torrent@vpn\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> ~/.bashrc

USER root

EXPOSE 8080

CMD ["/usr/local/bin/start-vpn.sh"]