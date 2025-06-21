#!/bin/bash

# Enhanced health check script with retry logic and multiple endpoints
# Based on VPN troubleshooting analysis recommendations

set -e

# Function to test VPN connectivity with multiple endpoints and retry logic
test_vpn_connectivity() {
    local attempts=3
    local timeout=15
    
    for i in $(seq 1 $attempts); do
        # Primary test endpoint
        if timeout $timeout curl -s --interface tun0 https://httpbin.org/ip > /tmp/ip_test 2>&1; then
            return 0
        fi
        
        # Fallback endpoint if primary fails
        if timeout $timeout curl -s --interface tun0 https://icanhazip.com > /tmp/ip_test2 2>&1; then
            return 0
        fi
        
        # Third fallback endpoint
        if timeout $timeout curl -s --interface tun0 https://api.ipify.org > /tmp/ip_test3 2>&1; then
            return 0
        fi
        
        if [ $i -lt $attempts ]; then
            echo "Connectivity test $i/$attempts failed, retrying in 5 seconds..."
            sleep 5
        fi
    done
    
    return 1
}

# Check if VPN interface exists and has proper routing
if ! ip route | grep -q "0.0.0.0/1.*tun0"; then
    echo "FAILED: No VPN default route found"
    echo "Debug: Current routes:"
    ip route | grep tun || echo "No tun routes found"
    exit 1
fi

if ! ip route | grep -q "128.0.0.0/1.*tun0"; then
    echo "WARNING: Incomplete VPN routing (missing 128.0.0.0/1 route)"
fi

# Test connectivity with retry logic
echo "Testing VPN connectivity..."
if ! test_vpn_connectivity; then
    echo "FAILED: Cannot reach internet through VPN interface after multiple attempts"
    echo "Debug info:"
    echo "VPN interface status:"
    ip addr show tun0 2>/dev/null || echo "tun0 interface not found"
    echo "Routing table:"
    ip route | head -10
    echo "DNS resolution test:"
    nslookup google.com || echo "DNS resolution failed"
    exit 1
fi

# Get external IP from successful test
EXTERNAL_IP="unknown"
if [ -f /tmp/ip_test ]; then
    EXTERNAL_IP=$(grep -o '"origin":"[^"]*"' /tmp/ip_test 2>/dev/null | cut -d'"' -f4 || echo "unknown")
elif [ -f /tmp/ip_test2 ]; then
    EXTERNAL_IP=$(cat /tmp/ip_test2 | tr -d '\n' 2>/dev/null || echo "unknown")
elif [ -f /tmp/ip_test3 ]; then
    EXTERNAL_IP=$(cat /tmp/ip_test3 | tr -d '\n' 2>/dev/null || echo "unknown")
fi

# Cleanup temp files
rm -f /tmp/ip_test /tmp/ip_test2 /tmp/ip_test3

# Check if external IP looks like a VPN IP (enhanced check)
if [[ $EXTERNAL_IP =~ ^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.) ]]; then
    echo "WARNING: External IP appears to be local/private: $EXTERNAL_IP"
    echo "This might indicate a VPN configuration issue"
fi

# Service-specific health checks will be added by individual scripts
SERVICE_STATUS="base"
if [ -n "$SERVICE_TYPE" ]; then
    case "$SERVICE_TYPE" in
        "javascript")
            # Check if development server port is accessible (if running)
            if curl -s --max-time 5 http://localhost:8080 > /dev/null 2>&1; then
                SERVICE_STATUS="dev server accessible"
            else
                SERVICE_STATUS="dev server not running"
            fi
            ;;
        "torrenting")
            # Check qBittorrent is running and accessible
            if ! curl -s --max-time 5 http://localhost:8081 > /dev/null; then
                echo "FAILED: qBittorrent Web UI not accessible"
                exit 1
            fi
            SERVICE_STATUS="qBittorrent accessible"
            ;;
    esac
fi

echo "HEALTHY: VPN connected, External IP: $EXTERNAL_IP, Service: $SERVICE_STATUS"
exit 0