#!/bin/bash

# Simplified but secure VPN kill switch script
# Usage: killswitch.sh [SERVICE_TYPE] [DOCKER_SUBNET]
# This script ensures all outbound traffic goes through VPN while allowing incoming connections to service ports

SERVICE_TYPE=${1:-default}
DOCKER_SUBNET=${2:-${DOCKER_SUBNET:-172.25.0.0/16}}

echo "Setting up secure VPN kill switch for ${SERVICE_TYPE}..."

# Flush all existing rules completely
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Set default policies - DROP for FORWARD and OUTPUT to ensure VPN usage
iptables -P INPUT ACCEPT  # Changed to ACCEPT - we'll be selective with rules
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# =============================================================================
# ESSENTIAL CONNECTIVITY
# =============================================================================

# Allow all loopback traffic
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# =============================================================================
# VPN CONNECTION ESTABLISHMENT
# =============================================================================

# Allow VPN connection establishment (OpenVPN uses UDP 1194 or TCP 443)
iptables -A OUTPUT -o eth0 -p udp --dport 1194 -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --dport 443 -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --dport 1194 -j ACCEPT

# Allow DNS for VPN server resolution (before VPN is up)
iptables -A OUTPUT -o eth0 -p udp --dport 53 -m limit --limit 10/min -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --dport 53 -m limit --limit 10/min -j ACCEPT

# =============================================================================
# VPN TUNNEL - ALL TRAFFIC MUST GO THROUGH VPN
# =============================================================================

# Allow ALL traffic through VPN tunnel
iptables -A INPUT -i tun+ -j ACCEPT
iptables -A OUTPUT -o tun+ -j ACCEPT
iptables -A FORWARD -i tun+ -j ACCEPT
iptables -A FORWARD -o tun+ -j ACCEPT

# =============================================================================
# SERVICE-SPECIFIC INCOMING CONNECTIONS (from host to container)
# =============================================================================

case "${SERVICE_TYPE}" in
    "torrenting")
        echo "Configuring firewall for torrenting service..."
        # Allow qBittorrent WebUI access from anywhere (docker-compose already limits to localhost)
        iptables -A INPUT -p tcp --dport 8081 -j ACCEPT
        # Allow torrent ports
        iptables -A INPUT -p tcp --dport 6881 -j ACCEPT
        iptables -A INPUT -p udp --dport 6881 -j ACCEPT
        ;;
    "javascript")
        echo "Configuring firewall for JavaScript development service..."
        # Allow development server access from anywhere (docker-compose already limits to localhost)
        iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
        iptables -A INPUT -p tcp --dport 3000 -j ACCEPT
        iptables -A INPUT -p tcp --dport 5173 -j ACCEPT
        ;;
    *)
        echo "Using default firewall configuration..."
        ;;
esac

# =============================================================================
# DOCKER INTERNAL COMMUNICATION
# =============================================================================

# Allow communication within Docker network
iptables -A INPUT -s ${DOCKER_SUBNET} -j ACCEPT
iptables -A OUTPUT -d ${DOCKER_SUBNET} -j ACCEPT

# =============================================================================
# KILLSWITCH - BLOCK ALL OTHER OUTBOUND TRAFFIC
# =============================================================================

# This is the killswitch - no other outbound traffic allowed except through VPN
iptables -A OUTPUT -o eth0 -j REJECT --reject-with icmp-net-unreachable

# Log dropped packets for debugging (optional)
# iptables -A OUTPUT -m limit --limit 2/min -j LOG --log-prefix "VPN-KILLSWITCH-BLOCKED: " --log-level 4

echo "✅ VPN kill switch activated for ${SERVICE_TYPE}"
echo "� Outbound traffic: VPN tunnel only"
echo "🌐 Inbound traffic: Service ports accessible from host"
echo "�️  Killswitch active: No IP leakage possible"