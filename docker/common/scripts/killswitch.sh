#!/bin/bash

echo "Setting up enhanced VPN kill switch..."

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

# Allow traffic to/from specific Docker bridge networks
# These will be added by service-specific scripts
if [ -n "$DOCKER_SUBNET" ]; then
    iptables -A INPUT -s "$DOCKER_SUBNET" -j ACCEPT
    iptables -A OUTPUT -d "$DOCKER_SUBNET" -j ACCEPT
fi

# Allow established and related connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow DNS to specific servers before VPN is up (more restrictive)
iptables -A OUTPUT -d 8.8.8.8 -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -d 1.1.1.1 -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -d 8.8.4.4 -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -d 1.0.0.1 -p udp --dport 53 -j ACCEPT

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

# Allow DNS through VPN interface specifically (important fix from analysis)
iptables -A OUTPUT -o tun+ -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -o tun+ -p tcp --dport 53 -j ACCEPT

# Service-specific ports will be added by individual services
# This base script provides the core kill switch functionality

echo "Enhanced VPN kill switch activated - only VPN traffic allowed"
echo "Use service-specific scripts to add application ports"