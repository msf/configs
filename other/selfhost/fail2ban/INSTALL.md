# Fail2ban Installation & Setup

## Install fail2ban
```bash
sudo apt install fail2ban -y
```

## Deploy configs
```bash
# Copy filters
sudo cp ~/configs/other/selfhost/fail2ban/filter.d/* /etc/fail2ban/filter.d/

# Copy jail config
sudo cp ~/configs/other/selfhost/fail2ban/jail.d/caddy.local /etc/fail2ban/jail.d/

# Restart fail2ban
sudo systemctl restart fail2ban
sudo systemctl status fail2ban
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
