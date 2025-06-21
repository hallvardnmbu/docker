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
    # Start OpenVPN with better configuration
    openvpn --config /etc/openvpn/nordvpn/nordvpn.ovpn \
            --auth-user-pass /etc/openvpn/nordvpn/auth.txt \
            --script-security 2 \
            --up-delay \
            --up-restart \
            --down-pre \
            --daemon
    
    echo "Waiting for VPN connection..."
    sleep 15
    
    # Verify VPN connection with better checking
    echo "Verifying VPN connection..."
    for i in {1..60}; do
        if ip route | grep -q tun0; then
            echo "VPN interface detected, verifying external connectivity..."
            sleep 5
            # Test external connectivity through VPN
            if curl -s --max-time 15 --interface tun0 https://httpbin.org/ip > /dev/null; then
                EXTERNAL_IP=$(curl -s --max-time 10 --interface tun0 https://httpbin.org/ip | grep -o '"origin":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
                echo "VPN connection established successfully"
                echo "External IP: $EXTERNAL_IP"
                break
            fi
        fi
        if [ $i -eq 60 ]; then
            echo "ERROR: VPN connection failed or external connectivity not working"
            echo "Debug info:"
            ip route | grep tun || echo "|No tun interface found"
            echo "OpenVPN logs:"
            journalctl -u openvpn --no-pager -n 20 || echo "No systemd logs available"
            exit 1
        fi
        echo "Waiting for VPN... ($i/60)"
        sleep 2
    done
    
    # Create qBittorrent config directory with proper ownership
    mkdir -p /home/config/qBittorrent
    chown -R playground:playground /home/config
    
    # Copy default qBittorrent configuration if not exists
    if [ ! -f "/home/config/qBittorrent/qBittorrent.conf" ]; then
        echo "Setting up qBittorrent configuration..."
        cp /etc/qbittorrent/qbittorrent.conf /home/config/qBittorrent/qBittorrent.conf
        chown playground:playground /home/config/qBittorrent/qBittorrent.conf
        echo "Default qBittorrent configuration applied"
    fi
    
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
    echo "Access Web UI at: http://localhost:8081"
    echo "Downloads will be saved to: /home/downloads"
    
    # Start qBittorrent as playground user with proper configuration
    echo "y" | sudo -u playground /usr/bin/qbittorrent-nox \
        --webui-port=8081 \
        --save-path=/home/downloads \
        --profile=/home/config \
        --no-daemon &
    
    # Wait a bit for qBittorrent to start
    sleep 10
    
    # Verify qBittorrent is running
    if curl -s --max-time 5 http://localhost:8081 > /dev/null; then
        echo "qBittorrent started successfully and is accessible"
    else
        echo "WARNING: qBittorrent might not be fully started yet, check logs if issues persist"
    fi
    
    # Keep container running and monitor processes
    wait
else
    echo "Starting qBittorrent as non-root user..."
    echo "y" | exec /usr/bin/qbittorrent-nox \
        --webui-port=8081 \
        --save-path=/home/downloads \
        --profile=/home/config
fi