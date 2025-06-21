FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl wget git vim htop build-essential sudo dos2unix \
    openvpn iptables qbittorrent-nox iproute2 net-tools dnsutils \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -d /home -s /bin/bash playground && \
    echo "playground:lavik" | chpasswd && \
    usermod -aG sudo playground

RUN mkdir -p /etc/openvpn/nordvpn /home/downloads /home/downloads/incomplete /home/config && \
    chown -R playground:playground /home/downloads /home/config

WORKDIR /home

# Copy centralized VPN scripts
COPY ../vpn/scripts/killswitch.sh /usr/local/bin/killswitch.sh
COPY ../vpn/scripts/health-check.sh /usr/local/bin/health-check.sh
COPY ../vpn/scripts/start-vpn.sh /usr/local/bin/start-vpn.sh
COPY scripts/qbittorrent.conf /etc/qbittorrent/qbittorrent.conf
RUN dos2unix /usr/local/bin/killswitch.sh /usr/local/bin/health-check.sh /usr/local/bin/start-vpn.sh && \
    chmod +x /usr/local/bin/killswitch.sh /usr/local/bin/health-check.sh /usr/local/bin/start-vpn.sh && \
    mkdir -p /etc/qbittorrent && \
    ls -la /usr/local/bin/start-vpn.sh /usr/local/bin/killswitch.sh /usr/local/bin/health-check.sh

# Create .bashrc for playground user and set custom prompt
RUN touch /home/.bashrc && \
    chown playground:playground /home/.bashrc && \
    echo 'export PS1="\[\033[01;32m\]torrent@vpn\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> /home/.bashrc

EXPOSE 8081 6881

CMD ["/usr/local/bin/start-vpn.sh", "torrenting"]