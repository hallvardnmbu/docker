# Shared VPN Utilities

This directory contains shared VPN utilities used by all Docker services to eliminate code duplication and provide enhanced, reliable VPN functionality.

## 🔧 Improvements Made

Based on comprehensive VPN troubleshooting analysis, the following improvements have been implemented:

### 1. **Enhanced OpenVPN Startup**
- ✅ Process verification ensures OpenVPN actually starts
- ✅ Verbose logging with `/tmp/openvpn.log` for debugging
- ✅ Longer timeout (120s) for connection establishment
- ✅ Better error reporting with network diagnostics

### 2. **Improved VPN Verification**
- ✅ Multiple endpoint testing (httpbin.org, icanhazip.com, api.ipify.org)
- ✅ Proper routing verification (both 0.0.0.0/1 and 128.0.0.0/1 routes)
- ✅ Enhanced connectivity testing with 30s timeouts
- ✅ Retry logic for transient failures

### 3. **Fixed Kill Switch DNS Issues**
- ✅ DNS resolution through VPN interface specifically allowed
- ✅ More restrictive pre-VPN DNS (specific servers only)
- ✅ Better Docker network integration
- ✅ Service-specific port configuration

### 4. **Enhanced qBittorrent Startup** (Torrenting)
- ✅ Removed problematic `echo "y"` command
- ✅ Proper daemon startup verification
- ✅ Web UI accessibility testing with retry logic
- ✅ Better error diagnostics

### 5. **Better Health Checks**
- ✅ Multiple endpoint testing with fallbacks
- ✅ Retry logic for transient failures
- ✅ Enhanced debugging information
- ✅ Service-specific health verification

## 📁 File Structure

```
common/
├── README.md                    # This file
└── scripts/
    ├── killswitch.sh           # Enhanced base kill switch
    ├── health-check.sh         # Enhanced health checks with retry logic
    ├── start-vpn-base.sh       # Base VPN startup functionality
    ├── start-vpn-javascript.sh # JavaScript-specific VPN setup
    └── start-vpn-torrenting.sh # Torrenting-specific VPN setup
```

## 🚀 How It Works

### Base VPN Script (`start-vpn-base.sh`)
- Provides core VPN functionality used by all services
- Handles OpenVPN startup, verification, and error reporting
- Exports functions that services can use and override
- Configurable timeouts and service names

### Service-Specific Scripts
Each service has its own start script that:
1. Sources the base VPN script
2. Sets service-specific configuration
3. Calls `setup_base_vpn()` for core functionality
4. Adds service-specific kill switch rules
5. Starts service-specific applications

### Enhanced Kill Switch (`killswitch.sh`)
- Provides base iptables rules for VPN-only traffic
- Supports service-specific Docker subnet configuration
- Allows services to add their own port rules
- Fixed DNS resolution issues

### Health Check (`health-check.sh`)
- Tests VPN connectivity with multiple endpoints
- Provides retry logic for reliability
- Service-aware health checking
- Enhanced debugging information

## 🛠️ Usage

### For New Services

1. **Create service-specific start script:**
```bash
#!/bin/bash
set -euo pipefail

# Source the base VPN script
source /usr/local/bin/start-vpn-base.sh

# Service configuration
export SERVICE_NAME="my-service"
export DOCKER_SUBNET="172.xx.0.0/16"
export SERVICE_TYPE="my-service"

# Service-specific setup function
setup_my_service_killswitch() {
    # Add your ports to kill switch
    iptables -A INPUT -p tcp --dport 8080 -s 172.16.0.0/12 -j ACCEPT
    # ... more rules
}

# Override display function
display_service_info() {
    echo "My Service Ready!"
    # ... service info
}

# Main logic
if [ "$EUID" -eq 0 ]; then
    setup_base_vpn
    setup_my_service_killswitch
    # Start your service
else
    start_as_user
    exec /bin/bash
fi
```

2. **Update Dockerfile:**
```dockerfile
COPY common/scripts/killswitch.sh /usr/local/bin/killswitch.sh
COPY common/scripts/health-check.sh /usr/local/bin/health-check.sh
COPY common/scripts/start-vpn-base.sh /usr/local/bin/start-vpn-base.sh
COPY common/scripts/start-vpn-my-service.sh /usr/local/bin/start-vpn.sh
```

3. **Update docker-compose.yml:**
```yaml
environment:
  - SERVICE_TYPE=my-service
```

### Configuration Options

Set these in your service script before calling `setup_base_vpn()`:

- `VPN_TIMEOUT`: Connection timeout in seconds (default: 120)
- `SERVICE_NAME`: Display name for your service
- `DOCKER_SUBNET`: Your service's Docker subnet
- `SERVICE_TYPE`: Used for health check differentiation

## 🔍 Debugging

### Common Issues and Solutions

**VPN Connection Fails:**
```bash
# Check OpenVPN logs
docker exec <container> cat /tmp/openvpn.log

# Check network status
docker exec <container> ip route | grep tun
docker exec <container> nslookup google.com
```

**Service Not Accessible:**
```bash
# Run health check manually
docker exec <container> /usr/local/bin/health-check.sh

# Check iptables rules
docker exec <container> iptables -L -n
```

**DNS Issues:**
```bash
# Test DNS through VPN
docker exec <container> nslookup google.com
docker exec <container> curl --interface tun0 https://httpbin.org/ip
```

### Enhanced Logging

All scripts now provide verbose output including:
- OpenVPN process verification
- Routing table status
- DNS resolution testing
- External IP verification
- Service-specific status

## 🔄 Migration Guide

### From Old Scripts

1. **Remove old script directories** from services
2. **Update Dockerfiles** to use shared scripts
3. **Add SERVICE_TYPE** environment variable
4. **Test thoroughly** with new enhanced verification

### Backwards Compatibility

The new scripts maintain the same external interface:
- `/usr/local/bin/start-vpn.sh` still starts the service
- `/usr/local/bin/health-check.sh` still performs health checks
- Environment variables and Docker setup remain the same

## 📊 Benefits

1. **Reliability**: Enhanced verification and retry logic
2. **Maintainability**: Single source of truth for VPN logic
3. **Debuggability**: Comprehensive logging and error reporting
4. **Flexibility**: Service-specific customization supported
5. **Performance**: Faster startup with better timeout management

## 🔒 Security

- Kill switch remains active throughout startup
- DNS leaks prevented with VPN-specific DNS rules
- Process verification ensures VPN is actually running
- External IP verification confirms VPN connectivity
- Service isolation maintained with proper iptables rules

## 📝 Future Improvements

- [ ] Support for multiple VPN providers
- [ ] Automatic failover between VPN servers
- [ ] Metrics and monitoring integration
- [ ] Configuration validation tools
- [ ] Automated testing framework