# Secure Torrenting Container with NordVPN

This container provides a secure torrenting environment using qBittorrent with mandatory NordVPN protection. **ALL traffic is routed through the VPN with a kill switch to prevent IP leaks.**

## 🔒 Security Features

- **VPN Kill Switch**: Blocks all non-VPN traffic
- **No IP Leaks**: Traffic only flows through NordVPN tunnel
- **Isolated Environment**: Runs in containerized environment
- **Web-based Management**: qBittorrent Web UI
- **Resource Limits**: Memory and CPU constraints for safety

## 📋 Prerequisites

1. **NordVPN Account**: Active NordVPN subscription
2. **Docker & Docker Compose**: Installed on your system
3. **NordVPN Configuration Files**: Downloaded from your account

## 🚀 Setup Instructions

### Step 1: Get NordVPN Configuration

1. Log into your [NordVPN account](https://my.nordaccount.com/dashboard/nordvpn/)
2. Go to "NordVPN" → "Manual setup"
3. Download an OpenVPN configuration file (.ovpn) for your preferred server
4. Note your NordVPN service credentials (different from account login)

### Step 2: Configure VPN Files

Place your NordVPN files in the `data/vpn/` directory:

```bash
# Copy your .ovpn file (rename it to nordvpn.ovpn)
cp /path/to/your/server.ovpn ./data/vpn/nordvpn.ovpn

# Create authentication file
echo "your_nordvpn_username" > ./data/vpn/auth.txt
echo "your_nordvpn_password" >> ./data/vpn/auth.txt
```

**Important**: Use your NordVPN service credentials, NOT your account email/password!

### Step 3: Start the Container

```bash
# Build and start the container
docker-compose up -d

# Check logs to verify VPN connection
docker-compose logs -f torrenting
```

### Step 4: Access qBittorrent

1. Open your browser and go to: `http://localhost:8080`
2. Default credentials:
   - **Username**: `admin`
   - **Password**: `adminadmin`
3. **IMMEDIATELY change the default password** in Settings → Web UI

## 📁 Directory Structure

```
torrenting/
├── data/
│   ├── downloads/     # Your downloaded files
│   ├── config/        # qBittorrent configuration
│   └── vpn/           # NordVPN configuration files
│       ├── nordvpn.ovpn    # Your OpenVPN config
│       └── auth.txt        # Your credentials
├── docker-compose.yml
├── Dockerfile
├── start-vpn.sh
├── killswitch.sh
└── README.md
```

## 🔧 Configuration

### qBittorrent Settings

Recommended settings (accessible via Web UI → Settings):

1. **Downloads**:
   - Default save path: `/home/downloads`
   - Keep incomplete torrents in: `/home/downloads/incomplete`

2. **Connection**:
   - Listening Port: Use random port
   - Enable UPnP/NAT-PMP: Disabled (not needed with VPN)

3. **BitTorrent**:
   - Enable DHT: Yes
   - Enable PeX: Yes
   - Enable LSD: Yes

### VPN Server Selection

For optimal performance:
- Choose servers geographically close to you
- Use P2P-optimized servers (marked in NordVPN app)
- UDP configurations are typically faster than TCP

## 🛡️ Security Verification

### Check VPN Status

```bash
# Check container logs
docker-compose logs torrenting

# Verify IP address through container
docker exec playground-torrenting-vpn curl ifconfig.me

# Compare with your real IP
curl ifconfig.me
```

The IPs should be different!

### Monitor Kill Switch

The kill switch ensures that if VPN disconnects, all internet traffic stops:

```bash
# Monitor iptables rules
docker exec playground-torrenting-vpn iptables -L -n
```

## 🚨 Important Security Notes

1. **Never disable the VPN kill switch**
2. **Always verify your IP has changed** before downloading
3. **Use strong passwords** for qBittorrent Web UI
4. **Keep NordVPN credentials secure**
5. **Monitor logs regularly** for VPN connection issues

## 📊 Monitoring & Maintenance

### View Logs
```bash
# Real-time logs
docker-compose logs -f torrenting

# Check VPN connection
docker exec playground-torrenting-vpn ip route | grep tun0
```

### Restart Container
```bash
# Restart if VPN connection issues
docker-compose restart torrenting
```

### Update Container
```bash
# Rebuild with latest updates
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

## ⚠️ Troubleshooting

### VPN Won't Connect
1. Verify `.ovpn` file is valid
2. Check `auth.txt` credentials
3. Try different NordVPN server
4. Check NordVPN account status

### Can't Access Web UI
1. Ensure container is running: `docker-compose ps`
2. Check port binding: `netstat -tulpn | grep 8080`
3. Verify kill switch isn't blocking local traffic

### No Internet in Container
1. This is normal - kill switch blocks non-VPN traffic
2. Check VPN connection status in logs
3. Restart container if VPN failed to connect

## 🔄 Container Management

### Stop Container
```bash
docker-compose down
```

### Remove All Data
```bash
docker-compose down -v
sudo rm -rf data/
```

### Backup Downloads
```bash
# Create backup
tar -czf torrenting-backup-$(date +%Y%m%d).tar.gz data/downloads/
```

## 📝 Legal Notice

This container is provided for educational purposes. Users are responsible for:
- Complying with local laws and regulations
- Respecting copyright and intellectual property rights
- Using VPN services in accordance with their terms of service
- Following NordVPN's acceptable use policy

Always download only content you have legal right to access.