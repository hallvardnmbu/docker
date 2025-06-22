FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    build-essential \
    sudo \
    dos2unix \
    openvpn \
    iptables \
    qbittorrent-nox \
    iproute2 \
    net-tools \
    dnsutils \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -d /home -s /bin/bash playground && \
    echo "playground:lavik" | chpasswd && \
    usermod -aG sudo playground

RUN mkdir -p /etc/openvpn/nordvpn /home/data && \
    chown -R playground:playground /home/data

WORKDIR /home
RUN chown playground:playground /home

# Copy centralized VPN scripts
COPY vpn/scripts/killswitch.sh /usr/local/bin/killswitch.sh
COPY vpn/scripts/health-check.sh /usr/local/bin/health-check.sh
COPY vpn/scripts/start-vpn.sh /usr/local/bin/start-vpn.sh
COPY vpn/scripts/test-vpn.sh /usr/local/bin/test-vpn.sh
RUN dos2unix /usr/local/bin/killswitch.sh /usr/local/bin/health-check.sh /usr/local/bin/start-vpn.sh /usr/local/bin/test-vpn.sh && \
    chmod +x /usr/local/bin/killswitch.sh /usr/local/bin/health-check.sh /usr/local/bin/start-vpn.sh /usr/local/bin/test-vpn.sh

# Copy pre-configured qBittorrent configuration optimized for VPN use
RUN mkdir -p /home/.config/qBittorrent
COPY torrenting/scripts/qbittorrent.conf /home/.config/qBittorrent/qBittorrent.conf
RUN chown -R playground:playground /home/.config

# Copy entrypoint script that handles VPN setup as root, then switches to playground user
COPY torrenting/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create .bashrc for playground user and set custom prompt
RUN touch /home/.bashrc && \
    chown playground:playground /home/.bashrc && \
    echo 'export PS1="\[\033[01;32m\]torrent@vpn\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> /home/.bashrc

# Default command - use new entrypoint that handles VPN setup as root, then switches to playground user
CMD ["/usr/local/bin/entrypoint.sh", "torrenting"]

EXPOSE 8081 6881
