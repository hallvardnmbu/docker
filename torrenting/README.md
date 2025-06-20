# Secure Torrenting with NordVPN

Containerized qBittorrent with mandatory NordVPN protection and kill switch.

## Prerequisites

- Active NordVPN subscription
- Docker and Docker Compose
- E:\ drive available for downloads

## Setup

1. Download NordVPN OpenVPN configuration from your account dashboard
2. Place the .ovpn file at `data/vpn/nordvpn.ovpn`
3. Run `doc setup` to configure your NordVPN credentials and qBittorrent password

Note: Use NordVPN service credentials, not your account login.

## Usage

Start the container:
```bash
doc start torrenting
```

Access qBittorrent Web UI at `http://localhost:8081`
- Downloads will be saved to E:\ drive
- Use credentials from setup (admin / your_password)

## Security Features

- VPN kill switch blocks all non-VPN traffic
- Traffic only flows through NordVPN tunnel
- Container isolation with resource limits
- Health checks monitor VPN connection

## Verification

Check that your IP has changed:
```bash
# Container IP
doc shell torrenting curl ifconfig.me

# Your real IP
curl ifconfig.me
```

The IPs should be different.

## Troubleshooting

Container won't start: Verify NordVPN files are correctly placed and credentials are valid.

Can't access Web UI: Ensure container is running and port 8081 is not in use.

No internet in container: This is normal - the kill switch blocks non-VPN traffic. Check VPN connection in logs.

## Legal Notice

Users are responsible for complying with local laws and respecting copyright. Use only for legally authorized content.