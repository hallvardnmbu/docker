# Secure Torrenting with NordVPN

Containerized qBittorrent with mandatory NordVPN protection, kill switch, and comprehensive security features.

## ✨ Features

- **VPN Kill Switch**: Blocks all non-VPN traffic automatically
- **Interface Binding**: qBittorrent binds only to VPN interface
- **Cross-Platform**: Works on Linux, macOS, and Windows
- **Health Monitoring**: Automatic health checks and diagnostics
- **Secure Configuration**: Optimized qBittorrent settings for privacy
- **Easy Management**: CLI tool with status checking and testing

## Prerequisites

- Active NordVPN subscription
- Docker and Docker Compose
- Rust (for building the CLI tool)

## Quick Setup

1. **Initialize and Setup**:
   ```bash
   # Build the CLI tool (first time only)
   cargo build --release
   
   # Initialize project root
   ./target/release/doc init
   
   # Setup torrenting (creates directories and guides through config)
   ./target/release/doc setup
   ```

2. **Download NordVPN Configuration**:
   - Go to [NordVPN Manual Configuration](https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/openvpn/)
   - Download an OpenVPN configuration file
   - Place it at `torrenting/data/vpn/nordvpn.ovpn`

3. **Start and Test**:
   ```bash
   # Start the container
   doc start torrenting
   
   # Check status and health
   doc status torrenting
   
   # Run comprehensive tests
   doc test torrenting
   ```

## CLI Commands

| Command | Description |
|---------|-------------|
| `doc setup` | Initial setup wizard |
| `doc start torrenting` | Start the container |
| `doc status torrenting` | Check container and VPN status |
| `doc test torrenting` | Run comprehensive functionality tests |
| `doc logs torrenting` | View container logs |
| `doc shell torrenting` | Open shell in container |
| `doc stop torrenting` | Stop the container |
| `doc clean torrenting` | Remove container and images |

## Access

- **Web UI**: http://localhost:8081
- **Downloads**: `torrenting/data/downloads/` (auto-created)
- **Initial Login**: `admin` / `adminadmin`
- **Change password** immediately after first login!

## Security Features

### VPN Kill Switch
- Blocks ALL non-VPN traffic using iptables
- Only allows traffic through VPN tunnel (tun0)
- Prevents IP leaks if VPN disconnects
- Allows container management traffic

### qBittorrent Security
- **Interface Binding**: Only uses VPN interface
- **Anonymous Mode**: Enabled by default
- **Encryption**: Required for all connections
- **No UPnP**: Disabled for security
- **Subnet Whitelisting**: Web UI only accessible from Docker networks

### Network Isolation
- Container runs in isolated Docker network
- No direct internet access without VPN
- Health checks verify VPN functionality
- External IP monitoring

## Troubleshooting

### Quick Diagnostics
```bash
# Check everything at once
doc test torrenting

# Check detailed status
doc status torrenting

# View logs
doc logs torrenting
```

### Common Issues

**Container won't start**:
- Verify NordVPN files: `ls torrenting/data/vpn/`
- Check credentials in `auth.txt`
- Run `doc logs torrenting` for details

**No internet in container**:
- This is normal! Kill switch blocks non-VPN traffic
- Check VPN connection: `doc test torrenting`
- Verify external IP is different from host

**Web UI not accessible**:
- Container might still be starting (wait 2-3 minutes)
- Check if port 8081 is in use: `netstat -tulpn | grep 8081`
- Verify container status: `doc status torrenting`

**Downloads not appearing**:
- Check downloads directory: `ls torrenting/data/downloads/`
- Verify permissions and ownership
- Check qBittorrent logs in Web UI

### Advanced Debugging

**Check VPN interface inside container**:
```bash
doc shell torrenting
ip route | grep tun0
curl --interface tun0 https://httpbin.org/ip
```

**Check kill switch rules**:
```bash
doc shell torrenting
iptables -L -n
```

**Monitor health checks**:
```bash
docker logs playground-torrenting | grep HEALTH
```

## Configuration Files

- `torrenting/data/vpn/nordvpn.ovpn` - OpenVPN configuration
- `torrenting/data/vpn/auth.txt` - NordVPN service credentials  
- `torrenting/data/config/qbt_password.txt` - Web UI password
- `torrenting/data/config/qBittorrent/qBittorrent.conf` - qBittorrent settings

## Performance Notes

- **Memory Limit**: 4GB (configurable in docker-compose.yml)
- **CPU Limit**: 4 cores (configurable)
- **Connection Limits**: 200 total, 50 per torrent
- **Port**: Fixed at 6881 for better connectivity

## Legal Notice

Users are responsible for complying with local laws and respecting copyright. Use only for legally authorized content.

## File Structure

```
torrenting/
├── docker-compose.yml       # Container configuration
├── Dockerfile              # Container image
├── README.md               # This file
├── scripts/
│   ├── start-vpn.sh        # VPN startup script
│   ├── killswitch.sh       # Network kill switch
│   ├── health-check.sh     # Health monitoring
│   └── qbittorrent.conf    # Default qBittorrent config
└── data/
    ├── vpn/                # VPN configuration files
    ├── config/             # qBittorrent configuration  
    └── downloads/          # Downloaded files
```