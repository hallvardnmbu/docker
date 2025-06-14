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
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for safety (password: lavik)
RUN useradd -m -d /home -s /bin/bash playground && \
    echo "playground:lavik" | chpasswd && \
    usermod -aG sudo playground

# Set up a working directory
WORKDIR /home
RUN chown playground:playground /home

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

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="~/.local/bin/:$PATH"

# Default command
CMD ["/bin/bash"]

# Expose a port for potential web applications
EXPOSE 8080
