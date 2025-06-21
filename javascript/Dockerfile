FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

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

# Copy entrypoint script that handles VPN setup as root, then switches to playground user
COPY javascript/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set up playground user environment (must be done as root before switching)
RUN echo 'alias ll="ls -la"' >> /home/.bashrc && \
    echo 'alias la="ls -A"' >> /home/.bashrc && \
    echo 'alias s="git status"' >> /home/.bashrc && \
    echo 'alias p="git push"' >> /home/.bashrc && \
    echo 'alias pl="git pull"' >> /home/.bashrc && \
    echo 'alias aa="git add --all"' >> /home/.bashrc && \
    echo 'alias ..="cd .."' >> /home/.bashrc && \
    echo 'alias ...="cd ../.."' >> /home/.bashrc && \
    echo 'export PS1="\[\033[01;32m\]playground@container\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> /home/.bashrc && \
    echo '' >> /home/.bashrc && \
    echo '# Git functions that take parameters' >> /home/.bashrc && \
    echo 'function b() { git checkout "$1"; }' >> /home/.bashrc && \
    echo 'function c() { git commit -m "$*"; }' >> /home/.bashrc && \
    echo 'function a() { git add "$@"; }' >> /home/.bashrc && \
    chown playground:playground /home/.bashrc

# Install bun for playground user
RUN su - playground -c 'curl -fsSL https://bun.sh/install | bash' && \
    echo 'export PATH="/home/.bun/bin:$PATH"' >> /home/.bashrc && \
    echo 'export PATH="/home/.bun/bin:$PATH"' >> /home/.profile && \
    chown playground:playground /home/.bashrc /home/.profile
ENV PATH="/home/.bun/bin:$PATH"
    
# Default command - use new entrypoint that handles VPN setup as root, then switches to playground user
CMD ["/usr/local/bin/entrypoint.sh", "javascript"]

# Expose a port for potential web applications
EXPOSE 8080
