#!/bin/bash

# Enable strict error handling
set -euo pipefail

echo "Starting secure torrenting container with NordVPN..."

# Check if running as root for initial setup
if [ "$EUID" -eq 0 ]; then
    echo "Setting up VPN kill switch..."
    /usr/local/bin/killswitch.sh
    
    # Check for NordVPN configuration
    if [ ! -f "/etc/openvpn/nordvpn/nordvpn.ovpn" ]; then
        echo "ERROR: NordVPN configuration file not found!"
        echo "Please place your NordVPN .ovpn file at /etc/openvpn/nordvpn/nordvpn.ovpn"
        echo "You can download this from your NordVPN account dashboard."
        exit 1
    fi
    
    if [ ! -f "/etc/openvpn/nordvpn/auth.txt" ]; then
        echo "ERROR: NordVPN authentication file not found!"
        echo "Please create /etc/openvpn/nordvpn/auth.txt with your credentials:"
        echo "Line 1: Your NordVPN username"
        echo "Line 2: Your NordVPN password"
        exit 1
    fi
    
    echo "Starting NordVPN connection..."
    # Start OpenVPN in background
    openvpn --config /etc/openvpn/nordvpn/nordvpn.ovpn --auth-user-pass /etc/openvpn/nordvpn/auth.txt --daemon
    
    # Wait for VPN connection to establish
    echo "Waiting for VPN connection..."
    sleep 10
    
    # Verify VPN connection
    for i in {1..30}; do
        if ip route | grep -q tun0; then
            echo "VPN connection established successfully!"
            break
        fi
        if [ $i -eq 30 ]; then
            echo "ERROR: VPN connection failed to establish!"
            exit 1
        fi
        echo "Waiting for VPN... ($i/30)"
        sleep 2
    done
    
    # Get external IP to verify VPN
    echo "Checking external IP..."
    EXTERNAL_IP=$(curl -s --max-time 10 ifconfig.me || echo "Could not determine IP")
    echo "External IP: $EXTERNAL_IP"
    
    # Switch to non-root user and start qBittorrent
    echo "Starting qBittorrent..."
    sudo -u playground /usr/bin/qbittorrent-nox \
        --webui-port=8080 \
        --save-path=/home/downloads \
        --profile=/home/config
else
    echo "Running as non-root user, starting qBittorrent directly..."
    exec /usr/bin/qbittorrent-nox \
        --webui-port=8080 \
        --save-path=/home/downloads \
        --profile=/home/config
fi