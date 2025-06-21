#!/bin/bash

set -euo pipefail

# Source the base VPN script
source /usr/local/bin/start-vpn-base.sh

# JavaScript service configuration
export SERVICE_NAME="JavaScript development container"
export DOCKER_SUBNET="172.25.0.0/16"
export SERVICE_TYPE="javascript"

# JavaScript-specific kill switch setup
setup_javascript_killswitch() {
    # Add JavaScript development ports to kill switch
    iptables -A INPUT -p tcp --dport 8080 -s 172.16.0.0/12 -j ACCEPT
    iptables -A INPUT -p tcp --dport 8080 -s 172.25.0.0/16 -j ACCEPT
    iptables -A INPUT -p tcp --dport 3000 -s 172.16.0.0/12 -j ACCEPT
    iptables -A INPUT -p tcp --dport 3000 -s 172.25.0.0/16 -j ACCEPT
    iptables -A INPUT -p tcp --dport 5173 -s 172.16.0.0/12 -j ACCEPT
    iptables -A INPUT -p tcp --dport 5173 -s 172.25.0.0/16 -j ACCEPT
    
    echo "JavaScript development ports configured in kill switch"
}

# Override the display_service_info function for JavaScript
display_service_info() {
    echo "JavaScript Development Environment Ready!"
    echo "Working directory: $(pwd)"
    echo ""
    echo "Available development servers:"
    echo "- Port 8080: Default development server"
    echo "- Port 3000: Node.js/React development server"
    echo "- Port 5173: Vite development server"
    echo ""
    echo "Development tools available:"
    echo "- Bun (modern JavaScript runtime)"
    echo "- Node.js and npm"
    echo "- Git and development utilities"
}

# Main execution logic
if [ "$EUID" -eq 0 ]; then
    # Setup base VPN
    setup_base_vpn
    
    # Add JavaScript-specific kill switch rules
    setup_javascript_killswitch
    
    # Display service-specific information
    display_service_info
    
    echo "Switching to playground user..."
    exec sudo -u playground -i /bin/bash
else
    # Running as playground user
    start_as_user
    exec /bin/bash
fi