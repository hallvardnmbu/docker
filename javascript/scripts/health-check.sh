#!/bin/bash

# Health check script for JavaScript container with VPN
# Verifies VPN connection, external IP, and container accessibility

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

# Check if development server port is accessible (if running)
if curl -s --max-time 5 http://localhost:8080 > /dev/null 2>&1; then
    DEV_SERVER_STATUS="accessible"
else
    DEV_SERVER_STATUS="not running"
fi

# Verify we're not leaking real IP (basic check)
EXTERNAL_IP=$(curl -s --max-time 10 --interface tun0 https://httpbin.org/ip | grep -o '"origin":"[^"]*"' | cut -d'"' -f4 || echo "unknown")

# Optional: Check if external IP looks like a VPN IP (not starting with common residential prefixes)
if [[ $EXTERNAL_IP =~ ^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.) ]]; then
    echo "WARNING: External IP appears to be local/private: $EXTERNAL_IP"
fi

echo "HEALTHY: VPN connected, External IP: $EXTERNAL_IP, Dev server: $DEV_SERVER_STATUS"
exit 0