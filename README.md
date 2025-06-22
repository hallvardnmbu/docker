<img src="window.jpg" style="width: 100%;"></img>

# doc

A simple Rust CLI tool to manage Docker Compose environments with VPN support.

## Quick Start

1. **Build the tool:**
   ```sh
   cargo build --release
   ```

2. **Add your VPN credentials to `.env`:**
   ```
   NORDVPN_USER=your_service_username
   NORDVPN_PASSWORD=your_service_password
   NORDVPN_COUNTRY=Norway
   ```

3. **Start services:**
   ```sh
   ./target/release/doc start javascript  # Development environment
   ./target/release/doc start torrenting  # Torrenting with qBittorrent
   ```

## Commands

```sh
doc list                    # List available services
doc start <service>         # Start service with VPN
doc shell <service>         # Access development container
doc status <service>        # Check container and VPN status
doc test <service>          # Test functionality
doc stop <service>          # Stop all containers
doc logs <service>          # View logs
```

## Available Services

- **javascript** - Bun development environment with snublejuice code access
- **torrenting** - qBittorrent with VPN protection
- **python** - Python development environment
- **rust** - Rust development environment

## VPN Features

- All traffic automatically routed through VPN using [gluetun](https://github.com/qdm12/gluetun)
- Built-in killswitch prevents traffic leaks
- Automatic VPN reconnection
- Health monitoring

## Requirements

- Docker and Docker Compose
- NordVPN account (service credentials)
- Rust (for building)