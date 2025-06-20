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
    
    # Create qBittorrent config directory with proper ownership
    mkdir -p /home/config/qBittorrent
    chown -R playground:playground /home/config
    
    # Display password info if custom password file exists
    if [ -f "/home/config/qbt_password.txt" ]; then
        QB_PASSWORD=$(cat /home/config/qbt_password.txt)
        echo "Custom qBittorrent password available in: /home/config/qbt_password.txt"
        echo "First login with: admin / adminadmin"
        echo "Then change password to: $QB_PASSWORD"
    else
        echo "Using qBittorrent default credentials: admin / adminadmin"
        echo "Change password immediately after first login!"
    fi
    
    echo "Starting qBittorrent..."
    echo "y" | sudo -u playground /usr/bin/qbittorrent-nox \
        --webui-port=8081 \
        --save-path=/home/downloads \
        --profile=/home/config
else
    echo "y" | exec /usr/bin/qbittorrent-nox \
        --webui-port=8081 \
        --save-path=/home/downloads \
        --profile=/home/config
fi