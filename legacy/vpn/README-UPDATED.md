# Updated VPN Configuration

This VPN setup has been simplified to allow host access to container services while maintaining secure VPN routing for all outbound traffic.

## What Changed

1. **Simplified Killswitch**: The firewall rules now:
   - Allow incoming connections to service ports from the host
   - Ensure ALL outbound traffic goes through VPN (killswitch active)
   - Automatically detect and configure Docker subnet
   - Allow established connections for better compatibility

2. **Port Accessibility**:
   - **Torrenting**: qBittorrent Web UI accessible at `http://localhost:8081`
   - **JavaScript**: Development ports accessible at `localhost:3000`, `localhost:5173`, `localhost:8080`

3. **Security Maintained**:
   - All downloads and peer connections still go through VPN
   - Killswitch prevents any IP leakage
   - No outbound traffic possible without VPN connection

## Quick Start

1. **Set up VPN configuration** (if not already done):
   ```bash
   # From host machine
   doc setup torrenting
   # or
   doc setup javascript
   ```

2. **Start the container**:
   ```bash
   doc start torrenting
   # or
   doc start javascript
   ```

3. **Test VPN connection** (from inside container):
   ```bash
   test-vpn.sh torrenting
   # or
   test-vpn.sh javascript
   ```

## Testing the Setup

The `test-vpn.sh` script performs comprehensive checks:

1. **VPN Interface**: Verifies tun0 is up
2. **Routing**: Confirms VPN routes are configured
3. **External Connectivity**: Tests connection through VPN
4. **Killswitch**: Verifies direct connections are blocked
5. **Service Access**: Tests service-specific functionality
6. **DNS**: Verifies DNS resolution works
7. **Firewall Rules**: Shows active iptables configuration

## Troubleshooting

### Cannot access Web UI from host
- Ensure container is running: `docker ps`
- Check logs: `docker logs playground-torrenting`
- Run test script inside container: `test-vpn.sh torrenting`
- Verify port binding: `docker port playground-torrenting`

### VPN not connecting
- Check VPN credentials in `/vpn/config/auth.txt`
- Verify OpenVPN config file exists: `/vpn/config/nordvpn.ovpn`
- Check container logs for OpenVPN errors
- Try a different VPN server configuration

### Slow performance
- This is normal with VPN - all traffic is routed through VPN server
- Try connecting to a closer VPN server
- Check VPN server load

## Security Notes

- The killswitch is always active - no outbound traffic without VPN
- Service ports are only accessible from localhost (configured in docker-compose.yml)
- All peer-to-peer traffic goes through VPN
- DNS queries are limited when VPN is down to prevent leaks

## How It Works

1. Container starts with `entrypoint.sh`
2. VPN setup runs as root:
   - Configures iptables killswitch
   - Starts OpenVPN connection
   - Waits for VPN to establish
3. Once VPN is up, switches to playground user
4. Starts the service (qBittorrent or development environment)
5. All outbound traffic forced through VPN tunnel
6. Incoming connections to service ports allowed from host