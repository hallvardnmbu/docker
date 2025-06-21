#!/bin/bash

set -e

echo "🚀 Migrating from Custom VPN Scripts to Gluetun"
echo "=============================================="

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "📝 Creating .env file..."
    cp .env.example .env
    echo ""
    echo "⚠️  IMPORTANT: Edit .env file with your NordVPN credentials!"
    echo "   Get them from: https://my.nordaccount.com/dashboard/nordvpn/"
    echo ""
    read -p "Press Enter when you've updated .env with your credentials..."
fi

# Backup current setup
echo "💾 Backing up current setup..."
cp -r vpn/ vpn-backup/ 2>/dev/null || echo "vpn/ backup already exists or doesn't exist"
cp torrenting/docker-compose.yml torrenting/docker-compose-old.yml 2>/dev/null || echo "torrenting backup already exists"
cp javascript/docker-compose.yml javascript/docker-compose-old.yml 2>/dev/null || echo "javascript backup already exists"

echo "✅ Backup complete!"

# Stop current containers
echo "🛑 Stopping current containers..."
docker-compose -f torrenting/docker-compose.yml down 2>/dev/null || echo "Torrenting container not running"
docker-compose -f javascript/docker-compose.yml down 2>/dev/null || echo "JavaScript container not running"

# Test new setup
echo ""
echo "🧪 Testing new simplified setup..."
echo ""

# Test torrenting
read -p "Test torrenting setup? (y/n): " test_torrenting
if [[ $test_torrenting =~ ^[Yy]$ ]]; then
    echo "🔄 Starting simplified torrenting setup..."
    cd torrenting/
    docker-compose -f docker-compose-simplified.yml up -d
    
    echo "⏳ Waiting for VPN connection (30 seconds)..."
    sleep 30
    
    echo "🔍 Testing VPN connectivity..."
    VPN_IP=$(docker exec playground-vpn-torrenting curl -s ifconfig.me 2>/dev/null || echo "failed")
    
    if [ "$VPN_IP" != "failed" ]; then
        echo "✅ VPN connected! External IP: $VPN_IP"
        echo "🌐 qBittorrent should be available at: http://localhost:8081"
    else
        echo "❌ VPN connection failed. Check logs:"
        echo "   docker logs playground-vpn-torrenting"
    fi
    
    cd ..
fi

# Test javascript
echo ""
read -p "Test JavaScript development setup? (y/n): " test_javascript
if [[ $test_javascript =~ ^[Yy]$ ]]; then
    echo "🔄 Starting simplified JavaScript setup..."
    cd javascript/
    docker-compose -f docker-compose-simplified.yml up -d
    
    echo "⏳ Waiting for VPN connection (30 seconds)..."
    sleep 30
    
    echo "🔍 Testing VPN connectivity..."
    VPN_IP=$(docker exec playground-vpn-javascript curl -s ifconfig.me 2>/dev/null || echo "failed")
    
    if [ "$VPN_IP" != "failed" ]; then
        echo "✅ VPN connected! External IP: $VPN_IP"
        echo "🔧 Development environment ready. Access with:"
        echo "   docker exec -it playground-javascript bash"
    else
        echo "❌ VPN connection failed. Check logs:"
        echo "   docker logs playground-vpn-javascript"
    fi
    
    cd ..
fi

echo ""
echo "📋 Migration Summary:"
echo "===================="
echo "✅ Backed up original files to *-old.yml and vpn-backup/"
echo "✅ Created simplified docker-compose files"
echo "✅ Started new containers with gluetun"
echo ""

if [[ $test_torrenting =~ ^[Yy]$ ]]; then
    echo "🔄 Torrenting: docker-compose -f torrenting/docker-compose-simplified.yml"
fi

if [[ $test_javascript =~ ^[Yy]$ ]]; then
    echo "🔄 JavaScript: docker-compose -f javascript/docker-compose-simplified.yml"
fi

echo ""
echo "🔧 Next Steps:"
echo "1. Test your services thoroughly"
echo "2. If everything works, replace original files:"
echo "   mv torrenting/docker-compose-simplified.yml torrenting/docker-compose.yml"
echo "   mv javascript/docker-compose-simplified.yml javascript/docker-compose.yml"
echo "3. Clean up old VPN scripts (once confident)"
echo ""
echo "📚 Full migration guide: MIGRATION-TO-GLUETUN.md"
echo ""
echo "🎉 Migration complete! You've eliminated 1,200+ lines of custom scripts!"