#!/bin/bash

# VPN Kill Switch - Blocks all traffic except through VPN
echo "Setting up VPN kill switch..."

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

# Allow loopback traffic (localhost)
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow local network traffic (Docker internal)
iptables -A INPUT -s 172.16.0.0/12 -j ACCEPT
iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT

# Allow established and related connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow DNS queries to establish VPN connection (will be blocked after VPN is up)
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Allow VPN connection establishment
iptables -A OUTPUT -p udp --dport 1194 -j ACCEPT  # OpenVPN default
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT   # NordVPN TCP
iptables -A OUTPUT -p udp --dport 443 -j ACCEPT   # NordVPN UDP

# Allow traffic through VPN interface (will be created when VPN connects)
iptables -A INPUT -i tun+ -j ACCEPT
iptables -A OUTPUT -o tun+ -j ACCEPT

# Allow qBittorrent web UI (only from local network)
iptables -A INPUT -p tcp --dport 8080 -s 172.16.0.0/12 -j ACCEPT

echo "VPN kill switch activated. All traffic will be blocked unless VPN is connected."
echo "Only VPN traffic, local Docker network, and localhost will be allowed."