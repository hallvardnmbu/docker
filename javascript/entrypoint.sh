#!/bin/bash
set -euo pipefail

# VPN setup must run as root
if [ "$EUID" -eq 0 ]; then
    echo "Running VPN setup as root..."
    
    # Run VPN setup
    /usr/local/bin/start-vpn.sh "${1:-javascript}"
    
    # Keep the container running without immediately dropping into bash
    # This allows `doc shell` to work properly
    echo "VPN setup complete. Container ready for connections."
    echo "Use 'doc shell javascript' to access the container."
    
    # Keep container running
    tail -f /dev/null
else
    echo "Already running as non-root user"
    exec bash
fi 