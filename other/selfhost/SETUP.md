# Setup Documentation

**Status**: tv.mfilipe.eu working with HTTPS

---

## What's Running

**Caddy** (Docker):
- Location: /srv/selfhost/caddy/
- Config: Caddyfile.production
- Cert: Let's Encrypt wildcard `*.mfilipe.eu` (DNS-01 via Gandi)
- Logs: Will be in /srv/logs/caddy/ (not configured yet)

**Jellyfin** (systemd):
- Service: `systemctl status jellyfin`
- Logs: /var/log/jellyfin/
- Port: 8096 (localhost only, behind Caddy)

---

## DNS Configuration

```
tv.mfilipe.eu  A     93.108.195.82
tv.mfilipe.eu  AAAA  2001:818:e3da:f300:63f8:2c40:e3df:65c1
```

Managed via Gandi API (see scripts/configure-dns.sh)

---

## Secrets

**Location**: `caddy/env` (NOT in git)
**Contents**:
```
GANDI_API_TOKEN=<token>
TZ=Europe/Lisbon
```

**FIXME**: Encrypt with Age before adding to git

---

## Deployment

```bash
# Deploy Caddy changes
cd ~/configs/other/selfhost/caddy
scp Caddyfile.production docker-compose.production.yml miguel@192.168.1.15:/srv/selfhost/caddy/
ssh miguel@192.168.1.15 'cd /srv/selfhost/caddy && docker compose restart caddy'

# View logs
ssh miguel@192.168.1.15 'docker logs -f caddy'

# Test
curl -I https://tv.mfilipe.eu
```

---

## Security

**Current**:
- HTTPS only (Let's Encrypt)
- Basic security headers
- No rate limiting
- No IP banning
- Basic Jellyfin password

**Immediate**:
1. Change Jellyfin password at https://tv.mfilipe.eu
2. Enable persistent logging to /srv/logs/
3. Install Fail2ban
4. Setup git repo

---

## Monitoring

**Jellyfin logs**:
```bash
ssh miguel@192.168.1.15 'tail -f /var/log/jellyfin/jellyfin$(date +%Y%m%d).log'
```

**Caddy logs** (after logging setup):
```bash
ssh miguel@192.168.1.15 'tail -f /srv/logs/caddy/access.log | jq'
```

---

## Fail2ban (TODO)

Install: `sudo apt install fail2ban`

Config: `/etc/fail2ban/jail.d/caddy.conf`
```ini
[caddy-jellyfin]
enabled = true
port = 443
filter = caddy-jellyfin
logpath = /srv/logs/caddy/access.log
maxretry = 5
bantime = 3600
```

Filter: `/etc/fail2ban/filter.d/caddy-jellyfin.conf`
```ini
[Definition]
failregex = .*"status":401.*"remote_ip":"<HOST>".*
```

---

## Next Actions

1. **Change Jellyfin password** (critical)
2. **Move Caddy to /srv/selfhost/caddy/**
3. **Configure logging to /srv/logs/**
4. **Setup git repo** with .gitignore
5. **Install Fail2ban**
6. **Add metrics export** to VictoriaMetrics

---

## Caddy Config Structure

```caddyfile
*.mfilipe.eu {
    tls {
        dns gandi {env.GANDI_API_TOKEN}  # DNS-01 challenge
    }
    
    @tv host tv.mfilipe.eu
    handle @tv {
        reverse_proxy localhost:8096  # Jellyfin
    }
    
    # Future: img.mfilipe.eu, metrics.mfilipe.eu
}
```

---

## Troubleshooting

**Cert issues**:
```bash
# Check cert
echo | openssl s_client -connect tv.mfilipe.eu:443 | openssl x509 -noout -dates

# Caddy logs
docker logs caddy | grep -i certificate
```

**DNS issues**:
```bash
dig tv.mfilipe.eu
```

**Service not accessible**:
```bash
# Check Caddy
docker ps | grep caddy
docker logs caddy --tail 20

# Check Jellyfin
systemctl status jellyfin
ss -tlnp | grep 8096
```
