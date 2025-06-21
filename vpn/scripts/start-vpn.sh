#!/bin/bash

set -euo pipefail

# Unified VPN startup script
# Usage: start-vpn.sh [SERVICE_TYPE] [VPN_TIMEOUT] [DOCKER_SUBNET]
# SERVICE_TYPE: torrenting, javascript, or default
# VPN_TIMEOUT: timeout in seconds (default: 120)
# DOCKER_SUBNET: Docker subnet (default: 172.25.0.0/16)

SERVICE_TYPE=${1:-default}
VPN_TIMEOUT=${2:-${VPN_TIMEOUT:-120}}
DOCKER_SUBNET=${3:-${DOCKER_SUBNET:-172.25.0.0/16}}

echo "Starting secure ${SERVICE_TYPE} container with NordVPN..."

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
    local timeout=10  # Reduced timeout for faster feedback
    
    # First check if tun0 interface is actually configured
    if ! ip addr show tun0 >/dev/null 2>&1; then
        echo "  - tun0 interface not ready"
        return 1
    fi
    
    # Test with multiple endpoints with shorter timeout
    echo "  - Testing connectivity through tun0..."
    if timeout $timeout curl -s --max-time $timeout --interface tun0 https://httpbin.org/ip > /tmp/ip_test 2>&1; then
        EXTERNAL_IP=$(cat /tmp/ip_test | grep -o '"origin":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
        echo "  - Connected! External IP: $EXTERNAL_IP"
        return 0
    fi
    
    # Alternative test with different endpoint
    echo "  - Trying alternate endpoint..."
    if timeout $timeout curl -s --max-time $timeout --interface tun0 https://icanhazip.com > /tmp/ip_test2 2>&1; then
        EXTERNAL_IP=$(cat /tmp/ip_test2 | tr -d '\n' || echo "unknown")
        echo "  - Connected! External IP: $EXTERNAL_IP"
        return 0
    fi
    
    # Third fallback
    echo "  - Trying final fallback endpoint..."
    if timeout $timeout curl -s --max-time $timeout --interface tun0 https://api.ipify.org > /tmp/ip_test3 2>&1; then
        EXTERNAL_IP=$(cat /tmp/ip_test3 | tr -d '\n' || echo "unknown")
        echo "  - Connected! External IP: $EXTERNAL_IP"
        return 0
    fi
    
    # Show debug info on failure
    echo "  - All connectivity tests failed. Debug info:"
    echo "    tun0 status: $(ip addr show tun0 2>/dev/null | grep 'inet ' || echo 'No IP assigned')"
    echo "    DNS resolution: $(nslookup google.com 2>&1 | head -2 || echo 'DNS failed')"
    echo "    Routing table: $(ip route | grep tun0 || echo 'No VPN routes')"
    echo "    Last curl error: $(cat /tmp/ip_test3 2>/dev/null || echo 'No error log')"
    echo "    OpenVPN process: $(pgrep openvpn > /dev/null && echo 'Running' || echo 'Not running')"
    
    return 1
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: VPN setup must run as root"
    exit 1
fi

echo "Setting up enhanced VPN kill switch..."
export DOCKER_SUBNET
/usr/local/bin/killswitch.sh "${SERVICE_TYPE}" "${DOCKER_SUBNET}"

# Check for NordVPN configuration - wait for it if missing
while [ ! -f "/etc/openvpn/nordvpn/nordvpn.ovpn" ] || [ ! -f "/etc/openvpn/nordvpn/auth.txt" ]; do
    echo "❌ VPN configuration files not found. Waiting for setup..."
    echo ""
    echo "Missing files:"
    [ ! -f "/etc/openvpn/nordvpn/nordvpn.ovpn" ] && echo "  - /etc/openvpn/nordvpn/nordvpn.ovpn"
    [ ! -f "/etc/openvpn/nordvpn/auth.txt" ] && echo "  - /etc/openvpn/nordvpn/auth.txt"
    echo ""
    echo "📋 To set up VPN configuration:"
    echo "   1. Run: doc setup ${SERVICE_TYPE}"
    echo "   2. Or manually create the files:"
    echo "      - Download OpenVPN config from: https://my.nordaccount.com/dashboard/nordvpn/"
    echo "      - Create auth.txt with your NordVPN service credentials"
    echo ""
    echo "⏳ Checking again in 30 seconds..."
    sleep 30
done

echo "✅ VPN configuration files found!"

# Initialize OpenVPN log file with proper permissions
echo "Initializing OpenVPN logging..."
touch /tmp/openvpn.log
chmod 644 /tmp/openvpn.log
echo "$(date): Starting NordVPN connection..." > /tmp/openvpn.log

echo "Starting NordVPN connection..."
# Start OpenVPN with enhanced configuration and logging
openvpn --config /etc/openvpn/nordvpn/nordvpn.ovpn \
        --auth-user-pass /etc/openvpn/nordvpn/auth.txt \
        --script-security 2 \
        --log-append /tmp/openvpn.log \
        --verb 4 \
        --pull \
        --persist-tun \
        --persist-key \
        --comp-lzo no \
        --daemon

# Verify OpenVPN process is running
echo "Verifying OpenVPN process startup..."
sleep 5
if ! verify_openvpn_process; then
    exit 1
fi

# Fix DNS configuration to use external DNS servers instead of Docker's embedded DNS
# This needs to happen BEFORE connectivity testing
echo "🔧 Configuring DNS for VPN compatibility..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

echo "Waiting for VPN connection (timeout: ${VPN_TIMEOUT}s)..."

# Enhanced VPN verification with better routing checks
connectivity_attempts=0
max_connectivity_attempts=3

for i in $(seq 1 $VPN_TIMEOUT); do
    # Check for proper routing (both halves of the internet)
    if ip route | grep -q "0.0.0.0/1.*tun0" && ip route | grep -q "128.0.0.0/1.*tun0"; then
        echo "VPN routing detected, testing connectivity... (attempt $((connectivity_attempts + 1))/$max_connectivity_attempts)"
        
        if test_vpn_connectivity; then
            echo "✅ VPN connection established successfully"
            echo "External IP: $EXTERNAL_IP"
            break
        fi
        
        connectivity_attempts=$((connectivity_attempts + 1))
        if [ $connectivity_attempts -ge $max_connectivity_attempts ]; then
            echo "❌ VPN connectivity test failed after $max_connectivity_attempts attempts"
            echo "Routing is configured but external connectivity is not working."
            echo "This might be due to:"
            echo "  - Firewall blocking VPN traffic"
            echo "  - DNS resolution issues"
            echo "  - VPN server connectivity problems"
            echo ""
            echo "OpenVPN logs:"
            cat /tmp/openvpn.log || echo "No OpenVPN logs available"
            exit 1
        fi
        
        echo "  - Connectivity test failed, waiting 10 seconds before retry..."
        sleep 10
    fi
    
    if [ $i -eq $VPN_TIMEOUT ]; then
        echo "❌ VPN connection setup failed after $((VPN_TIMEOUT / 60)) minutes"
        echo ""
        echo "Debug information:"
        echo "OpenVPN logs:"
        cat /tmp/openvpn.log || echo "No OpenVPN logs available"
        echo ""
        echo "Network interfaces:"
        ip addr show
        echo ""
        echo "Routing table:"
        ip route
        echo ""
        echo "DNS test:"
        nslookup google.com 2>&1 || echo "DNS resolution failed"
        exit 1
    fi
    
    # More informative progress updates
    if [ $((i % 15)) -eq 0 ]; then
        echo "⏳ Waiting for VPN connection... ($i/${VPN_TIMEOUT}s)"
        # Show basic connection status
        if ip route | grep -q tun0; then
            echo "  - tun0 interface exists"
            # Check if OpenVPN is still running
            if pgrep openvpn > /dev/null; then
                echo "  - OpenVPN process is running"
            else
                echo "  - ⚠️  OpenVPN process not found, connection may have failed"
            fi
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

echo "VPN setup complete for ${SERVICE_TYPE}"
echo "External IP: $EXTERNAL_IP"
echo "All traffic is now routed through VPN with kill switch protection"
echo ""

# Service-specific post-setup actions
case "${SERVICE_TYPE}" in
    "torrenting")
        echo "- qBittorrent will be accessible at http://localhost:8081"
        echo "- Downloads will be saved to /home/data/downloads"
        echo "- VPN kill switch active"
        ;;
    "javascript")
        echo "- Development server ports (3000, 5173, 8080) are accessible"
        echo "- All external traffic routed through VPN"
        echo "- VPN kill switch active"
        ;;
    *)
        echo "- VPN kill switch active"
        echo "- All external traffic routed through VPN"
        ;;
esac

# Cleanup temp files
rm -f /tmp/ip_test /tmp/ip_test2 /tmp/ip_test3

echo ""
echo "Running as playground user in VPN-protected environment"
echo "VPN Status: $(ip route | grep tun0 > /dev/null && echo 'Connected' || echo 'Not Connected')"
if ip route | grep -q tun0; then
    echo "External IP: $EXTERNAL_IP"
fi
echo ""