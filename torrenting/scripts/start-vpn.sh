#!/bin/bash

set -euo pipefail

echo "Starting secure torrenting container with NordVPN..."

if [ "$EUID" -eq 0 ]; then
    echo "Setting up VPN kill switch..."
    /usr/local/bin/killswitch.sh
    
    # Check for NordVPN configuration
    if [ ! -f "/etc/openvpn/nordvpn/nordvpn.ovpn" ]; then
        echo "ERROR: NordVPN configuration file not found at /etc/openvpn/nordvpn/nordvpn.ovpn"
        echo "Download from: https://my.nordaccount.com/dashboard/nordvpn/"
        exit 1
    fi
    
    if [ ! -f "/etc/openvpn/nordvpn/auth.txt" ]; then
        echo "ERROR: NordVPN authentication file not found at /etc/openvpn/nordvpn/auth.txt"
        echo "Create file with your NordVPN service credentials (username on line 1, password on line 2)"
        exit 1
    fi
    
    echo "Starting NordVPN connection..."
    openvpn --config /etc/openvpn/nordvpn/nordvpn.ovpn --auth-user-pass /etc/openvpn/nordvpn/auth.txt --daemon
    
    echo "Waiting for VPN connection..."
    sleep 10
    
    # Verify VPN connection
    for i in {1..30}; do
        if ip route | grep -q tun0; then
            echo "VPN connection established"
            break
        fi
        if [ $i -eq 30 ]; then
            echo "ERROR: VPN connection failed"
            exit 1
        fi
        echo "Waiting for VPN... ($i/30)"
        sleep 2
    done
    
    # Check external IP
    EXTERNAL_IP=$(curl -s --max-time 10 ifconfig.me || echo "Could not determine IP")
    echo "External IP: $EXTERNAL_IP"
    
    echo "Starting qBittorrent..."
    sudo -u playground /usr/bin/qbittorrent-nox \
        --webui-port=8080 \
        --save-path=/home/downloads \
        --profile=/home/config
else
    exec /usr/bin/qbittorrent-nox \
        --webui-port=8080 \
        --save-path=/home/downloads \
        --profile=/home/config
fi