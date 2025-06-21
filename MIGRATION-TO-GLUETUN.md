# Migration Guide: From Custom VPN Scripts to Gluetun

This guide shows you how to migrate from your complex custom VPN setup (1,200+ lines of scripts) to a simple gluetun-based solution (~50 lines).

## What Changes

### Before (Complex):
- 5 custom VPN scripts (1,200+ lines)
- Complex iptables management
- Custom health checks and monitoring
- Service-specific VPN logic
- Interactive setup wizards
- Custom DNS configuration
- Manual subnet detection

### After (Simple):
- Uses `qmcgaw/gluetun` container
- Automatic VPN management
- Built-in killswitch and health checks
- Environment variable configuration
- ~95% less code to maintain

## Migration Steps

### Step 1: Backup Current Setup

```bash
# Backup your current working setup
cp -r vpn/ vpn-backup/
cp torrenting/docker-compose.yml torrenting/docker-compose-old.yml
cp javascript/docker-compose.yml javascript/docker-compose-old.yml
```

### Step 2: Set Up Environment Variables

```bash
# Copy the example environment file
cp .env.example .env

# Edit with your NordVPN credentials
vim .env
```

Add your NordVPN service credentials (get from https://my.nordaccount.com/dashboard/nordvpn/):
```env
NORDVPN_USER=your_service_username
NORDVPN_PASSWORD=your_service_password
```

### Step 3: Test Torrenting Setup

```bash
# Stop current torrenting container
docker-compose -f torrenting/docker-compose.yml down

# Start with simplified setup
cd torrenting/
docker-compose -f docker-compose-simplified.yml up -d

# Check VPN status
docker logs playground-vpn-torrenting

# Test connectivity (should show VPN IP)
docker exec playground-vpn-torrenting curl ifconfig.me
```

Access qBittorrent at: http://localhost:8081

### Step 4: Test JavaScript Development

```bash
# Stop current javascript container  
docker-compose -f javascript/docker-compose.yml down

# Start with simplified setup
cd javascript/
docker-compose -f docker-compose-simplified.yml up -d

# Enter development environment
docker exec -it playground-javascript bash
```

### Step 5: Verify Everything Works

Test both setups:

#### Torrenting Tests:
```bash
# Check VPN IP
docker exec playground-vpn-torrenting curl ifconfig.me

# Check qBittorrent
curl http://localhost:8081

# Check killswitch (should fail)
docker exec playground-qbittorrent curl --max-time 5 ifconfig.me
```

#### JavaScript Tests:
```bash
# Check VPN IP  
docker exec playground-vpn-javascript curl ifconfig.me

# Start a dev server and test
docker exec -it playground-javascript bash
# Inside container: npm start or whatever you normally do
```

### Step 6: Replace Original Files (Once Confident)

```bash
# Replace original docker-compose files
mv torrenting/docker-compose.yml torrenting/docker-compose-old.yml
mv torrenting/docker-compose-simplified.yml torrenting/docker-compose.yml

mv javascript/docker-compose.yml javascript/docker-compose-old.yml  
mv javascript/docker-compose-simplified.yml javascript/docker-compose.yml
```

### Step 7: Clean Up (Optional)

Once everything works, you can remove the old VPN infrastructure:

```bash
# Remove old VPN scripts (keep backup!)
rm -rf vpn-backup/  # Only after you're 100% sure

# Remove VPN-related files from Dockerfiles
# (They're no longer needed)
```

## Key Differences

### Old Way:
```bash
# Complex startup
doc setup torrenting
doc start torrenting  
doc test torrenting

# Multiple scripts handling VPN
start-vpn.sh → killswitch.sh → health-check.sh → test-vpn.sh
```

### New Way:
```bash
# Simple startup
docker-compose up -d

# Everything handled by gluetun
# No manual scripts needed
```

## Troubleshooting

### VPN Not Connecting
```bash
# Check gluetun logs
docker logs playground-vpn-torrenting

# Common issues:
# - Wrong credentials in .env file
# - NordVPN account issues  
# - Firewall blocking VPN ports
```

### Can't Access Services
```bash
# Verify ports are mapped correctly
docker port playground-vpn-torrenting

# Check if VPN container is healthy
docker ps
```

### Want to Use Custom OpenVPN Config
If you prefer your existing `.ovpn` files:

```yaml
# In docker-compose file, change VPN config:
environment:
  - VPN_SERVICE_PROVIDER=custom
  - VPN_TYPE=openvpn
volumes:
  - ./vpn/config/nordvpn.ovpn:/gluetun/openvpn/custom.conf:ro
  - ./vpn/config/auth.txt:/gluetun/openvpn/auth.txt:ro
```

## Benefits of New Setup

1. **95% Less Code**: ~50 lines vs 1,200+ lines
2. **Community Maintained**: Updates and security patches handled automatically
3. **More Reliable**: Battle-tested by thousands of users
4. **Simpler Debugging**: Clear logs, established troubleshooting
5. **Multiple VPN Providers**: Easy to switch VPN providers
6. **Better Docker Integration**: Proper health checks, restart policies

## Rollback Plan

If you need to rollback:

```bash
# Stop new containers
docker-compose -f docker-compose-simplified.yml down

# Start old containers
docker-compose -f docker-compose-old.yml up -d
```

Your old setup files are preserved as `-old.yml` files.

## What You Can Delete (After Migration)

Once you're confident the new setup works:

```bash
# VPN scripts (1,200+ lines eliminated!)
rm vpn/scripts/start-vpn.sh
rm vpn/scripts/killswitch.sh  
rm vpn/scripts/health-check.sh
rm vpn/scripts/test-vpn.sh
rm vpn/scripts/setup-vpn.sh

# Simplify Dockerfiles (remove VPN-related copying)
# Update entrypoint scripts (remove VPN startup)

# Keep vpn/config/ if using custom configs
```

## Summary

**Before**: Enterprise-grade VPN solution with 1,200+ lines of custom scripts  
**After**: Simple, reliable VPN using proven community container

**Time to migrate**: ~30 minutes  
**Complexity reduction**: ~95%  
**Maintenance burden**: Nearly eliminated