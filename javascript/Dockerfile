FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Update package list and install essential tools + VPN dependencies
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
    dos2unix \
    openvpn \
    iptables \
    iproute2 \
    net-tools \
    dnsutils \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for safety (password: lavik)
RUN useradd -m -d /home -s /bin/bash playground && \
    echo "playground:lavik" | chpasswd && \
    usermod -aG sudo playground

# Create VPN and data directories
RUN mkdir -p /etc/openvpn/nordvpn /home/data && \
    chown -R playground:playground /home/data

# Set up a working directory
WORKDIR /home
RUN chown playground:playground /home

# Copy centralized VPN scripts
COPY ../vpn/scripts/killswitch.sh /usr/local/bin/killswitch.sh
COPY ../vpn/scripts/health-check.sh /usr/local/bin/health-check.sh
COPY ../vpn/scripts/start-vpn.sh /usr/local/bin/start-vpn.sh
RUN dos2unix /usr/local/bin/killswitch.sh /usr/local/bin/health-check.sh /usr/local/bin/start-vpn.sh && \
    chmod +x /usr/local/bin/killswitch.sh /usr/local/bin/health-check.sh /usr/local/bin/start-vpn.sh

# Switch to non-root user
USER playground

# Set up some useful aliases and environment
RUN echo 'alias ll="ls -la"' >> ~/.bashrc && \
    echo 'alias la="ls -A"' >> ~/.bashrc && \
    echo 'alias s="git status"' >> ~/.bashrc && \
    echo 'alias p="git push"' >> ~/.bashrc && \
    echo 'alias pl="git pull"' >> ~/.bashrc && \
    echo 'alias aa="git add --all"' >> ~/.bashrc && \
    echo 'alias ..="cd .."' >> ~/.bashrc && \
    echo 'alias ...="cd ../.."' >> ~/.bashrc && \
    echo 'export PS1="\[\033[01;32m\]playground@container\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> ~/.bashrc && \
    echo '' >> ~/.bashrc && \
    echo '# Git functions that take parameters' >> ~/.bashrc && \
    echo 'function b() { git checkout "$1"; }' >> ~/.bashrc && \
    echo 'function c() { git commit -m "$*"; }' >> ~/.bashrc && \
    echo 'function a() { git add "$@"; }' >> ~/.bashrc

# Install bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="~/.bun/bin:$PATH"

# Default command - start VPN and development environment
CMD ["/usr/local/bin/start-vpn.sh", "javascript"]

# Expose a port for potential web applications
EXPOSE 8080
