#!/bin/bash
# Phase 1: Setup persistent logging for Caddy

set -e

echo "=== Setting up Caddy Persistent Logging ==="

SERVER="miguel@192.168.1.15"
CADDY_DIR="~/selfhost/caddy"

# 1. Create log directory on server
echo "Creating log directory..."
ssh $SERVER 'sudo mkdir -p /var/log/caddy && sudo chown $(whoami):$(whoami) /var/log/caddy'

# 2. Update Caddyfile with logging
echo "Updating Caddyfile..."
cat > ~/configs/other/selfhost/caddy/Caddyfile.production <<'EOF'
{
	email miguel.filipe@hey.com
	
	# Admin API for metrics (localhost only)
	admin localhost:2019
	
	# Global access logging
	log {
		output file /var/log/caddy/access.log {
			roll_size 100mb
			roll_keep 10
			roll_keep_days 30
		}
		format json
		level INFO
	}
}

(security) {
	# Security headers
	header {
		X-Frame-Options "SAMEORIGIN"
		X-Content-Type-Options "nosniff"
		X-XSS-Protection "1; mode=block"
		-Server
	}
}

*.mfilipe.eu {
	tls {
		dns gandi {env.GANDI_API_TOKEN}
	}
	
	# Jellyfin - tv.mfilipe.eu
	@tv host tv.mfilipe.eu
	handle @tv {
		import security
		
		reverse_proxy localhost:8096 {
			header_up X-Forwarded-For {remote_host}
			header_up X-Real-IP {remote_host}
		}
		encode gzip
		
		# Log this subdomain separately
		log {
			output file /var/log/caddy/jellyfin.log {
				roll_size 50mb
				roll_keep 5
			}
			format json
		}
	}
	
	# Future: img.mfilipe.eu for Immich
	@img host img.mfilipe.eu
	handle @img {
		import security
		reverse_proxy localhost:2283
		encode gzip
	}
	
	# Future: metrics.mfilipe.eu for Grafana
	@metrics host metrics.mfilipe.eu
	handle @metrics {
		import security
		reverse_proxy localhost:3000
		encode gzip
	}
	
	# Catch-all
	handle {
		respond "Unknown subdomain" 404
	}
}
EOF

# 3. Update docker-compose to mount log directory
echo "Updating docker-compose..."
cat > ~/configs/other/selfhost/caddy/docker-compose.production.yml <<'EOF'
services:
  caddy:
    build: .
    container_name: caddy
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./Caddyfile.production:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
      - /var/log/caddy:/var/log/caddy
    env_file:
      - env

volumes:
  caddy_data:
  caddy_config:
EOF

# 4. Deploy to server
echo "Deploying to server..."
scp ~/configs/other/selfhost/caddy/Caddyfile.production $SERVER:$CADDY_DIR/
scp ~/configs/other/selfhost/caddy/docker-compose.production.yml $SERVER:$CADDY_DIR/

# 5. Restart Caddy
echo "Restarting Caddy..."
ssh $SERVER "cd $CADDY_DIR && docker compose restart caddy"

echo ""
echo "✅ Logging configured!"
echo ""
echo "View logs:"
echo "  ssh $SERVER 'tail -f /var/log/caddy/access.log | jq'"
echo "  ssh $SERVER 'tail -f /var/log/caddy/jellyfin.log | jq'"
echo ""
echo "Log files will rotate at 100MB, keeping 10 files (30 days)"
