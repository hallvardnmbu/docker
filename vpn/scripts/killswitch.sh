#!/bin/bash

# Unified VPN kill switch script
# Usage: killswitch.sh [SERVICE_TYPE] [DOCKER_SUBNET]
# SERVICE_TYPE: torrenting, javascript, or default
# DOCKER_SUBNET: Docker subnet (defaults to 172.25.0.0/16)

SERVICE_TYPE=${1:-default}
DOCKER_SUBNET=${2:-${DOCKER_SUBNET:-172.25.0.0/16}}

echo "Setting up VPN kill switch for ${SERVICE_TYPE}..."

# Flush existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Set default policies to DROP (block all)
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Allow loopback traffic
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow local network traffic (Docker internal networks)
iptables -A INPUT -s 172.16.0.0/12 -j ACCEPT
iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT

# Allow traffic to/from Docker bridge networks (configurable subnet)
iptables -A INPUT -s ${DOCKER_SUBNET} -j ACCEPT
iptables -A OUTPUT -d ${DOCKER_SUBNET} -j ACCEPT

# Allow established and related connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow DNS queries before VPN connection (essential for VPN connection)
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Allow VPN connection establishment (OpenVPN standard ports)
iptables -A OUTPUT -p udp --dport 1194 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
iptables -A OUTPUT -p udp --dport 443 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 1723 -j ACCEPT

# Allow traffic through VPN interface (most important rule)
iptables -A INPUT -i tun+ -j ACCEPT
iptables -A OUTPUT -o tun+ -j ACCEPT
iptables -A FORWARD -i tun+ -j ACCEPT
iptables -A FORWARD -o tun+ -j ACCEPT

# Service-specific firewall rules
case "${SERVICE_TYPE}" in
    "torrenting")
        echo "Configuring killswitch for torrenting service..."
        # Allow qBittorrent web UI from Docker networks
        iptables -A INPUT -p tcp --dport 8081 -s 172.16.0.0/12 -j ACCEPT
        iptables -A INPUT -p tcp --dport 8081 -s ${DOCKER_SUBNET} -j ACCEPT
        ;;
    "javascript")
        echo "Configuring killswitch for JavaScript development service..."
        # Allow web server/development ports from Docker networks
        iptables -A INPUT -p tcp --dport 8080 -s 172.16.0.0/12 -j ACCEPT
        iptables -A INPUT -p tcp --dport 8080 -s ${DOCKER_SUBNET} -j ACCEPT
        iptables -A INPUT -p tcp --dport 3000 -s 172.16.0.0/12 -j ACCEPT
        iptables -A INPUT -p tcp --dport 3000 -s ${DOCKER_SUBNET} -j ACCEPT
        iptables -A INPUT -p tcp --dport 5173 -s 172.16.0.0/12 -j ACCEPT
        iptables -A INPUT -p tcp --dport 5173 -s ${DOCKER_SUBNET} -j ACCEPT
        ;;
    *)
        echo "Using default killswitch configuration..."
        ;;
esac

# Log dropped packets for debugging (optional, remove in production)
iptables -A INPUT -j LOG --log-prefix "${SERVICE_TYPE^^}-DROPPED INPUT: " --log-level 4
iptables -A OUTPUT -j LOG --log-prefix "${SERVICE_TYPE^^}-DROPPED OUTPUT: " --log-level 4

echo "VPN kill switch activated for ${SERVICE_TYPE} - only VPN traffic allowed"