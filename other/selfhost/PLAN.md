# Self-Hosted Infrastructure Plan

**Domain**: mfilipe.eu (Gandi)  
**Server**: hopper (192.168.1.15)  
**Goal**: Photos (Immich), Media (Jellyfin), Metrics (Grafana) - self-hosted, secure, accessible

---

## Requirements

- HTTPS with valid certs (Let's Encrypt)
- Easy to remember domains (tv.mfilipe.eu, img.mfilipe.eu, etc)
- Minimal direct internet exposure
- Strong security (logging, IP banning, rate limiting)
- All configs in git, secrets encrypted
- Logs and monitoring integrated with existing VictoriaMetrics

---

## Current Status

✅ **Working**: tv.mfilipe.eu → HTTPS → Jellyfin  
⏳ **Next**: Logging, Fail2ban, Immich deployment

---

## Architecture

```
Internet → tv.mfilipe.eu (DNS A/AAAA → Home IP)
        → Router :443 → Server :443
        → Caddy (Let's Encrypt wildcard cert)
        → Jellyfin :8096
```

**No Tailscale Funnel** - Direct exposure with port 443 only  
**Why**: Tailscale Funnel terminates TLS, breaks custom domain certs

---

## Services

| Service | Domain | Port | Status |
|---------|--------|------|--------|
| Jellyfin | tv.mfilipe.eu | 8096 | ✅ Running |
| Immich | img.mfilipe.eu | 2283 | Planned |
| Grafana | metrics.mfilipe.eu | 3000 | Planned |

---

## Security Priorities

1. **Logging** - Persistent logs to /srv/logs/
2. **Fail2ban** - Auto-ban brute force attempts
3. **Strong passwords** - Jellyfin password change
4. **Git repo** - Version control with encrypted secrets
5. **Monitoring** - Export Caddy metrics to VictoriaMetrics

---

## File Structure

```
/srv/
├── selfhost/caddy/      # Caddy deployment
├── logs/caddy/          # Caddy logs
├── logs/jellyfin/       # Symlink to /var/log/jellyfin
└── configs/             # Config symlinks

~/configs/other/selfhost/  (Laptop)
├── caddy/
├── scripts/
├── secrets/             # NOT in git
└── PLAN.md, SETUP.md
```

---

## FIXMEs

- **Secrets**: Currently plaintext in `env` file → Use Age encryption
- **Logging**: Not persistent yet → Move to /srv/logs/
- **No IP banning**: Fail2ban needed
- **Basic password**: Jellyfin vulnerable

---

## TODOs

- Add Caddy metrics → VictoriaMetrics
- Deploy Immich for photos
- Consider Crowdsec vs Fail2ban
- GeoIP filtering (optional)
