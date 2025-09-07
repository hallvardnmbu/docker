FROM oven/bun:latest

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    build-essential \
    sudo \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /home/bun

# Set custom prompt
RUN echo 'export PS1="\[\033[01;32m\]javascript@gluetun\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> /home/bun/.bashrc

# Switch to the existing non-root user provided by the base image
USER bun

# Expose a port for potential web applications
EXPOSE 8080

# Simple entrypoint - just keep container running
CMD ["bash"]
