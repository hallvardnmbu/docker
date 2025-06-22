#!/bin/bash

# Unified health check script for VPN-enabled containers
# Usage: health-check.sh [SERVICE_TYPE]
# SERVICE_TYPE: torrenting, javascript, or default

SERVICE_TYPE=${1:-default}

echo "Running health check for ${SERVICE_TYPE} service..."

set -e

# Check if VPN interface exists
if ! ip route | grep -q tun0; then
    echo "FAILED: No VPN interface (tun0) found"
    exit 1
fi

# Check if we can reach external internet through VPN
if ! curl -s --max-time 10 --interface tun0 https://httpbin.org/ip > /dev/null; then
    echo "FAILED: Cannot reach internet through VPN interface"
    exit 1
fi

# Service-specific health checks
case "${SERVICE_TYPE}" in
    "torrenting")
        # Check qBittorrent is running and accessible
        if ! curl -s --max-time 5 http://localhost:8081 > /dev/null; then
            echo "FAILED: qBittorrent Web UI not accessible"
            exit 1
        fi
        SERVICE_STATUS="qBittorrent accessible"
        ;;
    "javascript")
        # Check if development server port is accessible (if running)
        if curl -s --max-time 5 http://localhost:8080 > /dev/null 2>&1; then
            SERVICE_STATUS="dev server accessible"
        elif curl -s --max-time 5 http://localhost:3000 > /dev/null 2>&1; then
            SERVICE_STATUS="dev server accessible on port 3000"
        elif curl -s --max-time 5 http://localhost:5173 > /dev/null 2>&1; then
            SERVICE_STATUS="dev server accessible on port 5173"
        else
            SERVICE_STATUS="dev server not running"
        fi
        ;;
    *)
        SERVICE_STATUS="service running"
        ;;
esac

# Verify we're not leaking real IP (basic check)
EXTERNAL_IP=$(curl -s --max-time 10 --interface tun0 https://httpbin.org/ip | grep -o '"origin":"[^"]*"' | cut -d'"' -f4 || echo "unknown")

# Optional: Check if external IP looks like a VPN IP (not starting with common residential prefixes)
if [[ $EXTERNAL_IP =~ ^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.) ]]; then
    echo "WARNING: External IP appears to be local/private: $EXTERNAL_IP"
fi

echo "HEALTHY: VPN connected, External IP: $EXTERNAL_IP, ${SERVICE_STATUS}"
exit 0