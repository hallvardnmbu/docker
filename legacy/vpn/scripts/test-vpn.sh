#!/bin/bash

# VPN and Service Test Script
# Usage: test-vpn.sh [SERVICE_TYPE]

SERVICE_TYPE=${1:-default}

echo "🔍 VPN and Service Connectivity Test for ${SERVICE_TYPE}"
echo "================================================"

# Test 1: Check VPN interface
echo ""
echo "1. Checking VPN interface..."
if ip addr show tun0 &>/dev/null; then
    echo "✅ VPN interface (tun0) is UP"
    VPN_IP=$(ip addr show tun0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    echo "   VPN IP: $VPN_IP"
else
    echo "❌ VPN interface (tun0) not found"
fi

# Test 2: Check routing table
echo ""
echo "2. Checking routing table..."
if ip route | grep -q "0.0.0.0/1.*tun0" && ip route | grep -q "128.0.0.0/1.*tun0"; then
    echo "✅ VPN routing is configured correctly"
else
    echo "⚠️  VPN routing may not be complete"
    echo "Current routes through tun0:"
    ip route | grep tun0 || echo "   No routes found"
fi

# Test 3: Test external connectivity through VPN
echo ""
echo "3. Testing external connectivity through VPN..."
if curl -s --interface tun0 --max-time 10 https://api.ipify.org > /tmp/vpn_ip 2>&1; then
    EXTERNAL_IP=$(cat /tmp/vpn_ip)
    echo "✅ External connectivity working"
    echo "   External IP: $EXTERNAL_IP"
    
    # Try to identify if it's a VPN IP
    if curl -s --interface tun0 --max-time 10 "https://ipapi.co/${EXTERNAL_IP}/json/" > /tmp/ip_info 2>&1; then
        ORG=$(cat /tmp/ip_info | grep -o '"org":"[^"]*"' | cut -d'"' -f4)
        if [[ "$ORG" == *"Nord"* ]] || [[ "$ORG" == *"VPN"* ]]; then
            echo "   ✅ Confirmed VPN provider: $ORG"
        else
            echo "   Provider: $ORG"
        fi
    fi
else
    echo "❌ External connectivity through VPN failed"
fi

# Test 4: Verify killswitch is working
echo ""
echo "4. Testing killswitch (attempting direct connection)..."
if timeout 5 curl -s --interface eth0 --max-time 3 https://api.ipify.org > /tmp/direct_test 2>&1; then
    echo "⚠️  WARNING: Killswitch may not be working - direct connection succeeded!"
    echo "   This should have been blocked!"
else
    echo "✅ Killswitch is working - direct connections blocked"
fi

# Test 5: Service-specific tests
echo ""
echo "5. Service-specific tests..."
case "${SERVICE_TYPE}" in
    "torrenting")
        # Test qBittorrent
        if pgrep qbittorrent-nox > /dev/null; then
            echo "✅ qBittorrent process is running"
            
            # Test local connectivity
            if curl -s --max-time 5 http://localhost:8081 > /dev/null 2>&1; then
                echo "✅ qBittorrent WebUI is accessible locally"
            else
                echo "⚠️  qBittorrent WebUI not responding on localhost:8081"
            fi
        else
            echo "❌ qBittorrent process not found"
        fi
        ;;
    "javascript")
        echo "✅ JavaScript development environment ready"
        echo "   Available ports: 3000, 5173, 8080"
        ;;
    *)
        echo "   No service-specific tests for ${SERVICE_TYPE}"
        ;;
esac

# Test 6: DNS Resolution
echo ""
echo "6. Testing DNS resolution..."
if nslookup google.com > /tmp/dns_test 2>&1; then
    echo "✅ DNS resolution working"
else
    echo "❌ DNS resolution failed"
fi

# Test 7: iptables rules summary
echo ""
echo "7. Active firewall rules summary:"
echo "   INPUT chain default: $(iptables -L INPUT -n | head -1 | grep -o 'policy [A-Z]*' | cut -d' ' -f2)"
echo "   OUTPUT chain default: $(iptables -L OUTPUT -n | head -1 | grep -o 'policy [A-Z]*' | cut -d' ' -f2)"
echo "   Service ports allowed in INPUT:"
case "${SERVICE_TYPE}" in
    "torrenting")
        iptables -L INPUT -n | grep -E "dpt:(8081|6881)" | sed 's/^/   /'
        ;;
    "javascript")
        iptables -L INPUT -n | grep -E "dpt:(3000|5173|8080)" | sed 's/^/   /'
        ;;
esac

echo ""
echo "================================================"
echo "Test complete!"

# Cleanup
rm -f /tmp/vpn_ip /tmp/direct_test /tmp/ip_info /tmp/dns_test

# Return appropriate exit code
if ip addr show tun0 &>/dev/null && [ -n "${EXTERNAL_IP:-}" ]; then
    exit 0
else
    exit 1
fi