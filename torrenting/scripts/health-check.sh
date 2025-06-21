#!/bin/bash

# Health check script for torrenting container
# Verifies VPN connection, external IP, and qBittorrent status

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

# Check qBittorrent is running and accessible
if ! curl -s --max-time 5 http://localhost:8081 > /dev/null; then
    echo "FAILED: qBittorrent Web UI not accessible"
    exit 1
fi

# Verify we're not leaking real IP (basic check)
EXTERNAL_IP=$(curl -s --max-time 10 --interface tun0 https://httpbin.org/ip | grep -o '"origin":"[^"]*"' | cut -d'"' -f4 || echo "unknown")

# Optional: Check if external IP looks like a VPN IP (not starting with common residential prefixes)
if [[ $EXTERNAL_IP =~ ^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.) ]]; then
    echo "WARNING: External IP appears to be local/private: $EXTERNAL_IP"
fi

echo "HEALTHY: VPN connected, External IP: $EXTERNAL_IP, qBittorrent accessible"
exit 0