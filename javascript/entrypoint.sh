#!/bin/bash
set -euo pipefail

# VPN setup must run as root
if [ "$EUID" -eq 0 ]; then
    echo "Running VPN setup as root..."
    
    # Run VPN setup
    /usr/local/bin/start-vpn.sh "${1:-javascript}"
    
    # Switch to playground user for the interactive shell
    echo "Switching to playground user..."
    exec su - playground -c "cd /home && exec bash"
else
    echo "Already running as non-root user"
    exec bash
fi 