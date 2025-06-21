#!/bin/bash

echo "🛡️  JavaScript Development Container VPN Setup"
echo "============================================="
echo ""

# Check if VPN directory exists
if [ ! -d "data/vpn" ]; then
    echo "Creating VPN configuration directory..."
    mkdir -p data/vpn
fi

# Check for OpenVPN configuration file
if [ ! -f "data/vpn/nordvpn.ovpn" ]; then
    echo "❌ NordVPN configuration file not found!"
    echo ""
    echo "Please download your NordVPN OpenVPN configuration:"
    echo "1. Go to: https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/openvpn/"
    echo "2. Download a configuration file"
    echo "3. Save it as: $(pwd)/data/vpn/nordvpn.ovpn"
    echo ""
    read -p "Press Enter when you've downloaded the configuration file..."
    
    if [ ! -f "data/vpn/nordvpn.ovpn" ]; then
        echo "❌ Configuration file still not found. Please download it first."
        exit 1
    fi
fi

# Check for authentication file
if [ ! -f "data/vpn/auth.txt" ]; then
    echo "📝 Creating NordVPN authentication file..."
    echo ""
    echo "You need your NordVPN service credentials (not your account login):"
    echo "Find them at: https://my.nordaccount.com/dashboard/nordvpn/"
    echo ""
    
    read -p "Enter your NordVPN service username: " nordvpn_user
    read -s -p "Enter your NordVPN service password: " nordvpn_pass
    echo ""
    
    echo "$nordvpn_user" > data/vpn/auth.txt
    echo "$nordvpn_pass" >> data/vpn/auth.txt
    chmod 600 data/vpn/auth.txt
    
    echo "✅ Authentication file created and secured."
else
    echo "✅ Authentication file already exists."
fi

echo ""
echo "🔍 Verifying setup..."

# Verify files exist
if [ -f "data/vpn/nordvpn.ovpn" ] && [ -f "data/vpn/auth.txt" ]; then
    echo "✅ All VPN configuration files present."
    echo ""
    echo "🚀 Ready to start! Run:"
    echo "   docker-compose up --build"
    echo ""
    echo "🔧 Useful commands:"
    echo "   docker exec playground-javascript /usr/local/bin/health-check.sh  # Check VPN status"
    echo "   docker exec -it playground-javascript /bin/bash                    # Shell access"
    echo "   docker-compose logs -f                                            # View logs"
else
    echo "❌ Setup incomplete. Please check the files and try again."
    exit 1
fi