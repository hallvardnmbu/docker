#!/bin/bash
set -euo pipefail

# VPN setup must run as root
if [ "$EUID" -eq 0 ]; then
    echo "Running VPN setup as root..."
    
    # Run VPN setup
    /usr/local/bin/start-vpn.sh "${1:-torrenting}"
    
    # Start qBittorrent as playground user (uses pre-configured VPN-optimized settings)
    echo "Starting qBittorrent as playground user..."
    export QBITTORRENT_ACCEPT_LEGAL_NOTICE=1
    # Configuration file already copied and configured for VPN use
    exec su - playground -c "cd /home && echo 'y' | qbittorrent-nox"
else
    echo "Already running as non-root user"
    export QBITTORRENT_ACCEPT_LEGAL_NOTICE=1
    exec bash -c "echo 'y' | qbittorrent-nox"
fi 