#!/bin/bash

echo "🔒 Secure Torrenting Container Setup"
echo "====================================="
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

echo "✅ Docker and Docker Compose are installed."
echo ""

# Create directories if they don't exist
mkdir -p data/downloads data/config data/vpn

echo "📁 Directory structure created."
echo ""

# Check if VPN config exists
if [ ! -f "data/vpn/nordvpn.ovpn" ]; then
    echo "⚠️  NordVPN configuration missing!"
    echo ""
    echo "To complete setup, you need to:"
    echo "1. Download your NordVPN OpenVPN config from: https://my.nordaccount.com/dashboard/nordvpn/"
    echo "2. Place it at: data/vpn/nordvpn.ovpn"
    echo "3. Create data/vpn/auth.txt with your NordVPN service credentials"
    echo ""
    echo "Example auth.txt content:"
    echo "your_nordvpn_service_username"
    echo "your_nordvpn_service_password"
    echo ""
else
    echo "✅ NordVPN configuration found."
fi

# Check if auth file exists
if [ ! -f "data/vpn/auth.txt" ]; then
    echo "⚠️  NordVPN authentication file missing!"
    
    read -p "Would you like to create the auth.txt file now? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Enter your NordVPN service credentials (NOT your account login):"
        read -p "Username: " nordvpn_user
        read -s -p "Password: " nordvpn_pass
        echo ""
        
        echo "$nordvpn_user" > data/vpn/auth.txt
        echo "$nordvpn_pass" >> data/vpn/auth.txt
        chmod 600 data/vpn/auth.txt
        
        echo "✅ Authentication file created."
    else
        echo "Please create data/vpn/auth.txt manually before starting the container."
    fi
else
    echo "✅ NordVPN authentication file found."
fi

echo ""
echo "🚀 Setup complete! To start the container:"
echo "   docker-compose up -d"
echo ""
echo "📖 For detailed instructions, see README.md"
echo ""
echo "🔗 Access qBittorrent Web UI at: http://localhost:8080"
echo "   Default login: admin / adminadmin (CHANGE THIS!)"
echo ""
echo "🔒 Remember: All traffic will be routed through NordVPN with a kill switch!"