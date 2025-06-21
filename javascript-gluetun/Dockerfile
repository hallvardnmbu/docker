FROM node:18-slim

# Install basic utilities (no VPN tools needed)
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    build-essential \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create playground user
RUN useradd -m -d /home -s /bin/bash playground && \
    echo "playground:lavik" | chpasswd && \
    usermod -aG sudo playground

# Set up directories
RUN mkdir -p /home/data && \
    chown -R playground:playground /home/data

WORKDIR /home
RUN chown playground:playground /home

# Set custom prompt
RUN touch /home/.bashrc && \
    chown playground:playground /home/.bashrc && \
    echo 'export PS1="\[\033[01;32m\]js-dev@vpn\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> /home/.bashrc

# Switch to playground user (no root VPN setup needed)
USER playground

# Set working directory
WORKDIR /home

# Simple entrypoint - just keep container running
CMD ["bash"]

EXPOSE 3000 5173 8080