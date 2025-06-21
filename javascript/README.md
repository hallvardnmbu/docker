# Secure JavaScript Development with NordVPN

Containerized JavaScript development environment with mandatory NordVPN protection, kill switch, and comprehensive security features.

## ✨ Features

- **VPN Kill Switch**: Blocks all non-VPN traffic automatically
- **JavaScript Development**: Bun, Node.js development tools
- **Multiple Port Support**: 8080, 3000, 5173 for various dev servers
- **Cross-Platform**: Works on Linux, macOS, and Windows
- **Health Monitoring**: Automatic health checks and diagnostics
- **Secure Configuration**: All traffic routed through VPN
- **Development Tools**: Git, vim, build tools, and JavaScript runtime

## Prerequisites

- Active NordVPN subscription
- Docker and Docker Compose

## Quick Setup

1. **Download NordVPN Configuration**:
   - Go to [NordVPN Manual Configuration](https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/openvpn/)
   - Download an OpenVPN configuration file
   - Place it at `javascript/data/vpn/nordvpn.ovpn`

2. **Create Authentication File**:
   ```bash
   # Create the auth file with your NordVPN service credentials
   echo "your-nordvpn-username" > javascript/data/vpn/auth.txt
   echo "your-nordvpn-password" >> javascript/data/vpn/auth.txt
   ```

3. **Start the Container**:
   ```bash
   cd javascript
   docker-compose up --build
   ```

4. **Verify VPN Connection**:
   ```bash
   # Check health status
   docker exec playground-javascript /usr/local/bin/health-check.sh
   
   # Check external IP
   docker exec playground-javascript curl --interface tun0 https://httpbin.org/ip
   ```

## Usage

### Starting Development Servers

Once inside the container, you can start various development servers:

```bash
# Bun development server (port 8080)
bun dev

# Node.js server (port 3000) 
npm start

# Vite development server (port 5173)
npm run dev
```

### Accessing Services

- **Port 8080**: http://localhost:8080 (Default)
- **Port 3000**: http://localhost:3000 (Node.js/React)
- **Port 5173**: http://localhost:5173 (Vite)

### Container Management

```bash
# Start container
docker-compose up -d

# View logs
docker-compose logs -f

# Shell access
docker exec -it playground-javascript /bin/bash

# Stop container
docker-compose down

# Health check
docker exec playground-javascript /usr/local/bin/health-check.sh
```

## Security Features

### VPN Kill Switch
- Blocks ALL non-VPN traffic using iptables
- Only allows traffic through VPN tunnel (tun0)
- Prevents IP leaks if VPN disconnects
- Allows container management traffic

### Network Isolation
- Container runs in isolated Docker network
- No direct internet access without VPN
- Health checks verify VPN functionality
- External IP monitoring
- Development ports only accessible from Docker networks

### Development Security
- All npm/bun packages downloaded through VPN
- Git operations secured through VPN
- API calls and external requests protected
- Anonymous browsing for development

## Troubleshooting

### Quick Diagnostics
```bash
# Check VPN status
docker exec playground-javascript /usr/local/bin/health-check.sh

# View detailed logs
docker-compose logs playground-javascript

# Check external IP
docker exec playground-javascript curl --interface tun0 https://httpbin.org/ip
```

### Common Issues

**Container won't start**:
- Verify NordVPN files exist: `ls javascript/data/vpn/`
- Check credentials in `auth.txt`
- Run `docker-compose logs` for details

**No internet in container**:
- This is normal! Kill switch blocks non-VPN traffic
- Verify VPN connection with health check
- Check that external IP is different from host

**Development server not accessible**:
- Container might still be starting (wait 2-3 minutes)
- Check if ports are in use on host
- Verify container status with `docker ps`

**Package installation fails**:
- Ensure VPN is connected before installing packages
- Check VPN interface: `docker exec playground-javascript ip route | grep tun0`
- Try installing packages after VPN is fully established

### Advanced Debugging

**Check VPN interface inside container**:
```bash
docker exec playground-javascript ip route | grep tun0
docker exec playground-javascript curl --interface tun0 https://httpbin.org/ip
```

**Check kill switch rules**:
```bash
docker exec playground-javascript iptables -L -n
```

**Monitor VPN connection**:
```bash
docker logs playground-javascript | grep VPN
```

## Configuration Files

- `javascript/data/vpn/nordvpn.ovpn` - OpenVPN configuration
- `javascript/data/vpn/auth.txt` - NordVPN service credentials
- `javascript/data/` - Your development files and projects

## Performance Notes

- **Memory Limit**: 2GB (configurable in docker-compose.yml)
- **CPU Limit**: 2 cores (configurable)
- **Available Ports**: 8080, 3000, 5173 (common development ports)
- **Runtime**: Bun (modern JavaScript runtime)

## Development Tips

1. **Project Structure**: Place your projects in `javascript/data/` to persist between container restarts
2. **Package Management**: Use `bun install` or `npm install` - all traffic goes through VPN
3. **API Development**: All external API calls are automatically routed through VPN
4. **Git Operations**: Clone repositories safely through VPN protection

## Legal Notice

Users are responsible for complying with local laws and respecting copyright. Use only for legally authorized development activities.

## File Structure

```
javascript/
├── docker-compose.yml       # Container configuration
├── Dockerfile              # Container image
├── README.md               # This file
├── scripts/
│   ├── start-vpn.sh        # VPN startup script
│   ├── killswitch.sh       # Network kill switch
│   └── health-check.sh     # Health monitoring
└── data/
    ├── vpn/                # VPN configuration files
    │   ├── nordvpn.ovpn   # OpenVPN config (you provide)
    │   └── auth.txt       # NordVPN credentials (you provide)
    └── [your-projects]/    # Your development projects
```