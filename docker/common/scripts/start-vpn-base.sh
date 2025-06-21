#!/bin/bash

set -euo pipefail

# Enhanced VPN startup script based on troubleshooting analysis
# This is the base script - services should source this and add their specific setup

# Default configuration - can be overridden by service scripts
VPN_TIMEOUT=${VPN_TIMEOUT:-120}
SERVICE_NAME=${SERVICE_NAME:-"container"}
DOCKER_SUBNET=${DOCKER_SUBNET:-"172.25.0.0/16"}

echo "Starting secure $SERVICE_NAME with NordVPN..."

# Function to verify OpenVPN process is running
verify_openvpn_process() {
    if ! pgrep openvpn > /dev/null; then
        echo "ERROR: OpenVPN failed to start"
        if [ -f /tmp/openvpn.log ]; then
            echo "OpenVPN logs:"
            cat /tmp/openvpn.log
        fi
        return 1
    fi
    return 0
}

# Function to test VPN connectivity with multiple endpoints
test_vpn_connectivity() {
    local timeout=30
    
    # Test with multiple endpoints and longer timeout
    if timeout $timeout curl -s --interface tun0 https://httpbin.org/ip > /tmp/ip_test 2>&1; then
        EXTERNAL_IP=$(cat /tmp/ip_test | grep -o '"origin":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
        return 0
    fi
    
    # Alternative test with different endpoint
    if timeout $timeout curl -s --interface tun0 https://icanhazip.com > /tmp/ip_test2 2>&1; then
        EXTERNAL_IP=$(cat /tmp/ip_test2 | tr -d '\n' || echo "unknown")
        return 0
    fi
    
    # Third fallback
    if timeout $timeout curl -s --interface tun0 https://api.ipify.org > /tmp/ip_test3 2>&1; then
        EXTERNAL_IP=$(cat /tmp/ip_test3 | tr -d '\n' || echo "unknown")
        return 0
    fi
    
    return 1
}

# Function to setup base VPN (should be called by service scripts)
setup_base_vpn() {
    if [ "$EUID" -ne 0 ]; then
        echo "ERROR: VPN setup must run as root"
        exit 1
    fi
    
    echo "Setting up enhanced VPN kill switch..."
    export DOCKER_SUBNET
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
    # Start OpenVPN with enhanced configuration and logging
    openvpn --config /etc/openvpn/nordvpn/nordvpn.ovpn \
            --auth-user-pass /etc/openvpn/nordvpn/auth.txt \
            --script-security 2 \
            --log /tmp/openvpn.log \
            --verb 3 \
            --up-delay \
            --up-restart \
            --down-pre \
            --daemon
    
    # Verify OpenVPN process is running
    echo "Verifying OpenVPN process startup..."
    sleep 5
    if ! verify_openvpn_process; then
        exit 1
    fi
    
    echo "Waiting for VPN connection (timeout: ${VPN_TIMEOUT}s)..."
    
    # Enhanced VPN verification with better routing checks
    for i in $(seq 1 $VPN_TIMEOUT); do
        # Check for proper routing (both halves of the internet)
        if ip route | grep -q "0.0.0.0/1.*tun0" && ip route | grep -q "128.0.0.0/1.*tun0"; then
            echo "VPN routing detected, testing connectivity..."
            sleep 3
            
            if test_vpn_connectivity; then
                echo "VPN connection established successfully"
                echo "External IP: $EXTERNAL_IP"
                break
            fi
        fi
        
        if [ $i -eq $VPN_TIMEOUT ]; then
            echo "ERROR: VPN connection failed after $((VPN_TIMEOUT / 60)) minutes"
            echo "OpenVPN logs:"
            cat /tmp/openvpn.log || echo "No OpenVPN logs available"
            echo "Network interfaces:"
            ip addr show
            echo "Routing table:"
            ip route
            echo "DNS test:"
            nslookup google.com || echo "DNS resolution failed"
            exit 1
        fi
        
        # More informative progress updates
        if [ $((i % 10)) -eq 0 ]; then
            echo "Waiting for VPN... ($i/${VPN_TIMEOUT}s)"
            # Show basic connection status
            if ip route | grep -q tun0; then
                echo "  - tun0 interface exists"
            else
                echo "  - waiting for tun0 interface"
            fi
        fi
        sleep 1
    done
    
    # Set up proper permissions for playground user
    chown -R playground:playground /home/data 2>/dev/null || true
    if [ -d /home/snublejuice ]; then
        chown -R playground:playground /home/snublejuice 2>/dev/null || true
    fi
    
    echo "VPN setup complete for $SERVICE_NAME"
    echo "External IP: $EXTERNAL_IP"
    echo "All traffic is now routed through VPN with kill switch protection"
    echo ""
    
    # Cleanup temp files
    rm -f /tmp/ip_test /tmp/ip_test2 /tmp/ip_test3
}

# Function to display service info (to be customized by services)
display_service_info() {
    echo "Base VPN service ready"
    echo "Working directory: $(pwd)"
}

# Function to start as playground user
start_as_user() {
    echo "Running as playground user in VPN-protected environment"
    echo "VPN Status: $(ip route | grep tun0 > /dev/null && echo 'Connected' || echo 'Not Connected')"
    if ip route | grep -q tun0; then
        EXTERNAL_IP=$(curl -s --max-time 10 --interface tun0 https://httpbin.org/ip 2>/dev/null | grep -o '"origin":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
        echo "External IP: $EXTERNAL_IP"
    fi
    echo ""
    display_service_info
    echo ""
}

# Export functions for use by service scripts
export -f setup_base_vpn
export -f display_service_info
export -f start_as_user
export -f verify_openvpn_process
export -f test_vpn_connectivity