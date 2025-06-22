# VPN Directory

This directory contains consolidated VPN scripts and configuration for all Docker services.

## Structure

```
vpn/
├── scripts/          # VPN utility scripts
│   ├── start-vpn.sh      # Main VPN startup script
│   ├── killswitch.sh     # Firewall killswitch script
│   ├── health-check.sh   # VPN health check script
│   └── setup-vpn.sh      # Interactive VPN setup script
├── config/           # Configuration templates
│   └── nordvpn.ovpn  # NordVPN config
└── README.md         # This file
```

## Scripts

### start-vpn.sh
Main VPN connection script that handles:
- Firewall killswitch setup
- OpenVPN connection establishment
- Connection verification
- Service-specific configuration

Usage: `start-vpn.sh [SERVICE_TYPE] [VPN_TIMEOUT] [DOCKER_SUBNET]`

### killswitch.sh
Configures iptables firewall rules to prevent traffic leakage outside VPN.
Supports different service types with appropriate port allowances.

Usage: `killswitch.sh [SERVICE_TYPE] [DOCKER_SUBNET]`

### health-check.sh
Verifies VPN connection status and service accessibility.

Usage: `health-check.sh [SERVICE_TYPE]`

### setup-vpn.sh
Interactive script for initial VPN configuration setup.

Usage: `setup-vpn.sh [SERVICE_TYPE] [DATA_DIR]`

## Service Types

The scripts support the following service types:

- **torrenting**: Configured for qBittorrent with port 8081 access
- **javascript**: Configured for development servers (ports 3000, 5173, 8080)
- **default**: Basic VPN configuration without service-specific ports

## Configuration

1. Download your NordVPN OpenVPN configuration from:
   https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/openvpn/

2. Place the `.ovpn` file in your service's `data/vpn/` directory as `nordvpn.ovpn`

3. Create an `auth.txt` file in the same directory with your NordVPN service credentials:
   ```
   your-service-username
   your-service-password
   ```

4. Ensure proper file permissions:
   ```bash
   chmod 600 data/vpn/auth.txt
   ```

## Docker Integration

These scripts are designed to be used within Docker containers and assume:
- Running as root for network configuration
- Standard Docker networking (172.16.0.0/12, configurable subnets)
- OpenVPN and iptables availability
- Standard Unix utilities (curl, ip, etc.)

## Security

- All scripts implement VPN killswitch functionality
- Private files (auth.txt, passwords) are created with restricted permissions (600)
- External IP verification prevents traffic leakage
- Service-specific firewall rules minimize attack surface