# Fail2ban Setup

## Structure
```
/srv/selfhost/fail2ban/
├── filter.d/
│   ├── caddy-auth.conf
│   └── caddy-404.conf
└── jail.d/
    └── caddy.local

/etc/fail2ban/
├── filter.d/
│   ├── caddy-auth.conf -> /srv/selfhost/fail2ban/filter.d/caddy-auth.conf
│   └── caddy-404.conf -> /srv/selfhost/fail2ban/filter.d/caddy-404.conf
└── jail.d/
    └── caddy.local -> /srv/selfhost/fail2ban/jail.d/caddy.local
```

## Install
```bash
sudo apt install fail2ban -y
```

## Deploy (on hopper)
```bash
# Copy repo to /srv
sudo cp -r ~/configs/other/selfhost/fail2ban /srv/selfhost/

# Set ownership
sudo chown -R root:adm /srv/selfhost/fail2ban
sudo chmod -R 2775 /srv/selfhost/fail2ban

# Create symlinks
sudo ln -sf /srv/selfhost/fail2ban/filter.d/caddy-auth.conf /etc/fail2ban/filter.d/
sudo ln -sf /srv/selfhost/fail2ban/filter.d/caddy-404.conf /etc/fail2ban/filter.d/
sudo ln -sf /srv/selfhost/fail2ban/jail.d/caddy.local /etc/fail2ban/jail.d/

# Test filters before enabling
fail2ban-regex /srv/logs/caddy/access.log /etc/fail2ban/filter.d/caddy-404.conf

# Restart fail2ban
sudo systemctl restart fail2ban
sudo systemctl status fail2ban

# Verify jails are running
sudo fail2ban-client status
```

## Test filters
```bash
# Test auth filter (should match 401/403 in JSON logs)
sudo fail2ban-regex /srv/logs/caddy/access.log /etc/fail2ban/filter.d/caddy-auth.conf

# Test 404 filter
sudo fail2ban-regex /srv/logs/caddy/access.log /etc/fail2ban/filter.d/caddy-404.conf
```

## Monitor
```bash
# Check jail status
sudo fail2ban-client status caddy-auth
sudo fail2ban-client status caddy-404

# Watch bans in real-time
sudo tail -f /var/log/fail2ban.log

# List currently banned IPs
sudo iptables -L -n | grep DROP
```

## Unban IP (if needed)
```bash
sudo fail2ban-client set caddy-auth unbanip <IP>
sudo fail2ban-client set caddy-404 unbanip <IP>
```

## Config Summary
- **caddy-auth**: 10 failures (401/403) in 5min → 1 day ban
- **caddy-404**: 20 failures (404) in 2min → 1 day ban
- Uses iptables to drop all traffic from banned IPs
- Runs as root (required for iptables manipulation)

## Deployment from local machine
```bash
# Copy to server
scp -r ~/configs/other/selfhost/fail2ban 192.168.1.15:/tmp/

# SSH and deploy
ssh 192.168.1.15 'sudo cp -r /tmp/fail2ban /srv/selfhost/ && \
  sudo chown -R root:adm /srv/selfhost/fail2ban && \
  sudo chmod -R 2775 /srv/selfhost/fail2ban && \
  sudo ln -sf /srv/selfhost/fail2ban/filter.d/* /etc/fail2ban/filter.d/ && \
  sudo ln -sf /srv/selfhost/fail2ban/jail.d/* /etc/fail2ban/jail.d/ && \
  sudo systemctl restart fail2ban'
```
