#!/bin/bash

# Unified VPN setup script
# Usage: setup-vpn.sh [SERVICE_TYPE] [PROJECT_ROOT]
# SERVICE_TYPE: torrenting, javascript, or default
# PROJECT_ROOT: Project root directory (for common VPN config)

SERVICE_TYPE=${1:-default}
PROJECT_ROOT=${2:-$(pwd)}

echo "🛡️  ${SERVICE_TYPE^} Container VPN Setup"

# Create common VPN directory if it doesn't exist
VPN_DIR="${PROJECT_ROOT}/vpn/config"
if [ ! -d "${VPN_DIR}" ]; then
    echo "Creating common VPN configuration directory..."
    mkdir -p "${VPN_DIR}"
fi

# Check for OpenVPN configuration file
OVPN_FILE="${VPN_DIR}/nordvpn.ovpn"
if [ ! -f "${OVPN_FILE}" ]; then
    echo "❌ NordVPN configuration file not found!"
    echo ""
    echo "Please download your NordVPN OpenVPN configuration:"
    echo "1. Go to: https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/openvpn/"
    echo "2. Download a server configuration file"
    echo "3. Save it as: $(pwd)/${OVPN_FILE}"
    echo ""
    echo "Checking again in 3 seconds..."
    sleep 3
    if [ ! -f "${OVPN_FILE}" ]; then
        echo "Configuration file still not found. Please download it and run this script again."
        exit 1
    fi
fi

# Check/create authentication file
AUTH_FILE="${VPN_DIR}/auth.txt"
if [ ! -f "${AUTH_FILE}" ]; then
    echo "📝 Creating NordVPN authentication file..."
    echo ""
    echo "You need your NordVPN service credentials (not your account login):"
    echo "Find them at: https://my.nordaccount.com/dashboard/nordvpn/"
    echo ""
    
    read -p "Enter your NordVPN service username: " nordvpn_user
    read -s -p "Enter your NordVPN service password: " nordvpn_pass
    echo ""
    
    if [ -z "$nordvpn_user" ] || [ -z "$nordvpn_pass" ]; then
        echo "❌ Username and password cannot be empty"
        exit 1
    fi
    
    echo "$nordvpn_user" > "${AUTH_FILE}"
    echo "$nordvpn_pass" >> "${AUTH_FILE}"
    chmod 600 "${AUTH_FILE}"
    echo "✅ VPN credentials saved and secured"
fi

# Service-specific configuration
case "${SERVICE_TYPE}" in
    "torrenting")
        # Create additional directories for torrenting
        SERVICE_DATA_DIR="${PROJECT_ROOT}/torrenting/data"
        mkdir -p "${SERVICE_DATA_DIR}/config" "${SERVICE_DATA_DIR}/downloads"
        
        # Setup qBittorrent password if needed
        QBT_PASSWORD_FILE="${SERVICE_DATA_DIR}/config/qbt_password.txt"
        if [ ! -f "${QBT_PASSWORD_FILE}" ]; then
            echo ""
            echo "📝 Setting up qBittorrent Web UI password..."
            read -p "Enter qBittorrent password (or press Enter for default): " qbt_pass
            if [ -z "$qbt_pass" ]; then
                qbt_pass="SecureTorrent2024!"
            fi
            echo "$qbt_pass" > "${QBT_PASSWORD_FILE}"
            chmod 600 "${QBT_PASSWORD_FILE}"
            echo "✅ qBittorrent password configured: $qbt_pass"
        fi
        ;;
    "javascript")
        # Create additional directories for javascript development
        SERVICE_DATA_DIR="${PROJECT_ROOT}/javascript/data"
        mkdir -p "${SERVICE_DATA_DIR}/projects" "${SERVICE_DATA_DIR}/node_modules"
        echo "✅ JavaScript development directories created"
        ;;
esac

# Final verification
if [ -f "${OVPN_FILE}" ] && [ -f "${AUTH_FILE}" ]; then
    echo ""
    echo "✅ All VPN configuration files present."
    echo ""
    echo "📋 Setup Summary:"
    echo "   VPN Config: ${OVPN_FILE}"
    echo "   VPN Auth: ${AUTH_FILE}"
    echo "   Common VPN Directory: ${VPN_DIR}"
    echo ""
    echo "🚀 Next steps:"
    echo "   Start container: doc start ${SERVICE_TYPE}"
    echo "   Check VPN status: doc status ${SERVICE_TYPE}"
    echo "   Test functionality: doc test ${SERVICE_TYPE}"
    
    case "${SERVICE_TYPE}" in
        "torrenting")
            echo "   Access qBittorrent: http://localhost:8081"
            ;;
        "javascript")
            echo "   Development ports: 3000, 5173, 8080"
            ;;
    esac
else
    echo ""
    echo "❌ Setup incomplete. Missing required files:"
    [ ! -f "${OVPN_FILE}" ] && echo "   - ${OVPN_FILE}"
    [ ! -f "${AUTH_FILE}" ] && echo "   - ${AUTH_FILE}"
    exit 1
fi