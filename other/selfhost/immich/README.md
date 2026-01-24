# Immich Deployment

## Prerequisites
```bash
# ZFS dataset already created
zfs list | grep immich
# simple/immich          128K  1.59T   128K  /media/simple/immich
# simple/immich/postgres 128K  1.59T   128K  /media/simple/immich/postgres
```

## Deploy
```bash
# Copy configs to server
scp -r ~/configs/other/selfhost/immich 192.168.1.15:/tmp/
ssh 192.168.1.15 "sudo cp -r /tmp/immich /srv/selfhost/ && \
  sudo chown -R miguel:miguel /srv/selfhost/immich && \
  sudo chmod 2775 /srv/selfhost/immich"

# Start services
ssh 192.168.1.15 "cd /srv/selfhost/immich && docker compose up -d"

# Update Caddy
scp ~/configs/other/selfhost/caddy/Caddyfile.production 192.168.1.15:/srv/selfhost/caddy/
ssh 192.168.1.15 "cd /srv/selfhost/caddy && docker compose restart"
```

## Setup DNS
```bash
# Add DNS record for img.mfilipe.eu
# (Already covered by wildcard *.mfilipe.eu)
```

## First Time Setup
1. Visit https://img.mfilipe.eu
2. Create admin account (strong password!)
3. Install mobile app
4. Configure backup

## Monitoring
```bash
# Check logs
ssh 192.168.1.15 "docker logs -f immich_server"

# Check status
ssh 192.168.1.15 "cd /srv/selfhost/immich && docker compose ps"

# Check disk usage
ssh 192.168.1.15 "zfs list -o name,used,avail,refer | grep immich"
```
