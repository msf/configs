# Setup Documentation

**Status**: tv.mfilipe.eu working with HTTPS, fail2ban active

---

## What's Running

**Caddy** (Docker):
- Location: /srv/selfhost/caddy/
- Config: Caddyfile.production
- Cert: Let's Encrypt wildcard `*.mfilipe.eu` (DNS-01 via Gandi)
- Logs: /srv/logs/caddy/access.log (JSON format, HTTP access logs)

**Jellyfin** (systemd):
- Service: `systemctl status jellyfin`
- Logs: /var/log/jellyfin/
- Port: 8096 (localhost only, behind Caddy)
- Password: Changed (strong)

**Fail2ban** (systemd):
- Location: /srv/selfhost/fail2ban/ (symlinked to /etc/fail2ban/)
- Jails: caddy-auth (401/403), caddy-404 (scanner detection)
- Logs: /var/log/fail2ban.log
- Ban duration: 1 day

---

## DNS Configuration

```
tv.mfilipe.eu  A     93.108.195.82
tv.mfilipe.eu  AAAA  2001:818:e3da:f300:63f8:2c40:e3df:65c1
```

Managed via Gandi API (see scripts/configure-dns.sh)

---

## Directory Structure

```
/srv/
├── selfhost/
│   ├── caddy/          # Caddy reverse proxy (root:adm 2775)
│   │   ├── Caddyfile.production
│   │   ├── docker-compose.production.yml
│   │   ├── Dockerfile
│   │   └── env         # Gandi API token (NOT in git)
│   └── fail2ban/       # Fail2ban configs (root:adm 2775)
│       ├── filter.d/   # Symlinked to /etc/fail2ban/filter.d/
│       │   ├── caddy-auth.conf
│       │   └── caddy-404.conf
│       └── jail.d/     # Symlinked to /etc/fail2ban/jail.d/
│           └── caddy.local
├── logs/
│   ├── caddy/         # Caddy HTTP access logs (nobody:adm 2775)
│   │   └── access.log
│   └── jellyfin -> /var/log/jellyfin
└── configs/
    └── jellyfin -> /etc/jellyfin
```

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

## Next Actions

1. **Setup Immich** (photo management at img.mfilipe.eu)
2. **Add Caddy metrics** export to VictoriaMetrics
3. **Expose Grafana** at metrics.mfilipe.eu (consider VPN-only)

---

**Caddy**:
```bash
cd ~/configs/other/selfhost/caddy
scp Caddyfile.production docker-compose.production.yml 192.168.1.15:/srv/selfhost/caddy/
ssh 192.168.1.15 'cd /srv/selfhost/caddy && docker compose restart'
```

**Fail2ban** (see fail2ban/README.md):
```bash
# Copy configs to server
scp -r ~/configs/other/selfhost/fail2ban 192.168.1.15:/tmp/
ssh 192.168.1.15 'sudo cp -r /tmp/fail2ban /srv/selfhost/ && sudo chown -R root:adm /srv/selfhost/fail2ban'

# Create symlinks and restart
ssh 192.168.1.15 'sudo ln -sf /srv/selfhost/fail2ban/filter.d/* /etc/fail2ban/filter.d/ && \
  sudo ln -sf /srv/selfhost/fail2ban/jail.d/* /etc/fail2ban/jail.d/ && \
  sudo systemctl restart fail2ban'
```

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
