#!/bin/bash

set -euo pipefail

# Source the base VPN script
source /usr/local/bin/start-vpn-base.sh

# Torrenting service configuration
export SERVICE_NAME="torrenting container"
export DOCKER_SUBNET="172.27.0.0/16"
export SERVICE_TYPE="torrenting"

# Torrenting-specific kill switch setup
setup_torrenting_killswitch() {
    # Add qBittorrent web UI port to kill switch
    iptables -A INPUT -p tcp --dport 8081 -s 172.16.0.0/12 -j ACCEPT
    iptables -A INPUT -p tcp --dport 8081 -s 172.27.0.0/16 -j ACCEPT
    
    echo "qBittorrent web UI port configured in kill switch"
}

# Enhanced qBittorrent startup (fixes issues from analysis)
setup_qbittorrent() {
    echo "Setting up qBittorrent configuration..."
    
    # Create qBittorrent config directory with proper ownership
    mkdir -p /home/config/qBittorrent
    chown -R playground:playground /home/config
    
    # Copy default qBittorrent configuration if not exists
    if [ ! -f "/home/config/qBittorrent/qBittorrent.conf" ]; then
        echo "Applying default qBittorrent configuration..."
        cp /etc/qbittorrent/qbittorrent.conf /home/config/qBittorrent/qBittorrent.conf 2>/dev/null || echo "Default config not found, qBittorrent will create one"
        chown playground:playground /home/config/qBittorrent/qBittorrent.conf 2>/dev/null || true
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
}

# Enhanced qBittorrent startup (fixed from analysis)
start_qbittorrent() {
    echo "Starting qBittorrent..."
    echo "Access Web UI at: http://localhost:8081"
    echo "Downloads will be saved to: /home/downloads"
    
    # Start qBittorrent as playground user without the problematic echo
    sudo -u playground /usr/bin/qbittorrent-nox \
        --webui-port=8081 \
        --save-path=/home/downloads \
        --profile=/home/config \
        --daemon
    
    # Wait and verify properly with enhanced checking
    echo "Waiting for qBittorrent to start..."
    sleep 10
    
    for i in {1..30}; do
        if curl -s --max-time 5 http://localhost:8081 > /dev/null 2>&1; then
            echo "qBittorrent started successfully and is accessible"
            break
        fi
        if [ $i -eq 30 ]; then
            echo "ERROR: qBittorrent failed to start or become accessible"
            # Check if process is running
            if pgrep qbittorrent > /dev/null; then
                echo "qBittorrent process is running, but Web UI is not accessible"
                echo "This might be a configuration issue or port conflict"
            else
                echo "qBittorrent process is not running"
                echo "Check qBittorrent logs and configuration"
            fi
            exit 1
        fi
        echo "Waiting for qBittorrent Web UI... ($i/30)"
        sleep 2
    done
}

# Override the display_service_info function for torrenting
display_service_info() {
    echo "Secure Torrenting Environment Ready!"
    echo "Working directory: $(pwd)"
    echo ""
    echo "qBittorrent Web UI: http://localhost:8081"
    echo "Default credentials: admin / adminadmin"
    echo "Downloads directory: /home/downloads"
    echo ""
    echo "Security features:"
    echo "- VPN kill switch active"
    echo "- Interface binding to tun0"
    echo "- Anonymous mode enabled"
    echo "- Encryption required"
}

# Main execution logic
if [ "$EUID" -eq 0 ]; then
    # Setup base VPN
    setup_base_vpn
    
    # Add torrenting-specific kill switch rules
    setup_torrenting_killswitch
    
    # Setup qBittorrent configuration
    setup_qbittorrent
    
    # Start qBittorrent
    start_qbittorrent
    
    # Display service-specific information
    display_service_info
    
    echo ""
    echo "Container ready. Monitoring qBittorrent..."
    
    # Keep container running and monitor processes
    wait
else
    echo "Starting qBittorrent as non-root user..."
    # Fixed qBittorrent startup without problematic echo
    exec /usr/bin/qbittorrent-nox \
        --webui-port=8081 \
        --save-path=/home/downloads \
        --profile=/home/config
fi