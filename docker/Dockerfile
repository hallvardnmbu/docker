FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Update package list and install essential tools
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    tree \
    unzip \
    zip \
    build-essential \
    sudo \
    openvpn \
    iptables \
    qbittorrent-nox \
    iproute2 \
    net-tools \
    dnsutils \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for safety (password: lavik)
RUN useradd -m -d /home -s /bin/bash playground && \
    echo "playground:lavik" | chpasswd && \
    usermod -aG sudo playground

# Create directories for VPN config and downloads
RUN mkdir -p /etc/openvpn/nordvpn \
    /home/downloads \
    /home/config \
    && chown -R playground:playground /home/downloads /home/config

# Set up a working directory
WORKDIR /home
RUN chown playground:playground /home

# Copy VPN and startup scripts
COPY start-vpn.sh /usr/local/bin/start-vpn.sh
COPY killswitch.sh /usr/local/bin/killswitch.sh
RUN chmod +x /usr/local/bin/start-vpn.sh /usr/local/bin/killswitch.sh

# Set up some useful aliases and environment for both root and playground user
RUN echo 'alias ll="ls -la"' >> /root/.bashrc && \
    echo 'alias la="ls -A"' >> /root/.bashrc && \
    echo 'export PS1="\[\033[01;31m\]root@vpn-container\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> /root/.bashrc

USER playground
RUN echo 'alias ll="ls -la"' >> ~/.bashrc && \
    echo 'alias la="ls -A"' >> ~/.bashrc && \
    echo 'alias s="git status"' >> ~/.bashrc && \
    echo 'export PS1="\[\033[01;32m\]torrent@vpn-container\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> ~/.bashrc

# Switch back to root for VPN setup (script will handle user switching)
USER root

# Expose qBittorrent web UI port
EXPOSE 8080

# Default command starts VPN and qBittorrent
CMD ["/usr/local/bin/start-vpn.sh"]