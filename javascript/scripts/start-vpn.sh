#!/bin/bash

set -euo pipefail

echo "Starting secure JavaScript development container with NordVPN..."

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
            ip route | grep tun || echo "No tun interface found"
            echo "OpenVPN logs:"
            journalctl -u openvpn --no-pager -n 20 || echo "No systemd logs available"
            exit 1
        fi
        echo "Waiting for VPN... ($i/60)"
        sleep 2
    done
    
    # Set up proper permissions for playground user
    chown -R playground:playground /home/data /home/snublejuice
    
    echo "VPN setup complete. Starting JavaScript development environment..."
    echo "Available development servers:"
    echo "- Port 8080: Default development server"
    echo "- Port 3000: Node.js/React development server"
    echo "- Port 5173: Vite development server"
    echo ""
    echo "External IP: $EXTERNAL_IP"
    echo "All traffic is now routed through VPN with kill switch protection"
    echo ""
    
    # Switch to playground user and start interactive shell
    echo "Switching to playground user..."
    exec sudo -u playground -i /bin/bash
else
    echo "Running as playground user in VPN-protected environment"
    echo "VPN Status: $(ip route | grep tun0 > /dev/null && echo 'Connected' || echo 'Not Connected')"
    if ip route | grep -q tun0; then
        EXTERNAL_IP=$(curl -s --max-time 10 --interface tun0 https://httpbin.org/ip 2>/dev/null | grep -o '"origin":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
        echo "External IP: $EXTERNAL_IP"
    fi
    echo ""
    echo "JavaScript Development Environment Ready!"
    echo "Working directory: $(pwd)"
    echo ""
    exec /bin/bash
fi