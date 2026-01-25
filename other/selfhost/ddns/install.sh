#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

echo "Building ddns binary..."
go build -o ddns ddns.go

echo "Deploying to /srv/selfhost/ddns..."
sudo mkdir -p /srv/selfhost/ddns
sudo cp ddns /srv/selfhost/ddns/
sudo cp ddns.service /etc/systemd/system/
sudo cp ddns.timer /etc/systemd/system/

# Create env file if it doesn't exist
if [ ! -f /srv/selfhost/ddns/env ]; then
    echo "Creating /srv/selfhost/ddns/env - EDIT THIS FILE WITH YOUR TOKEN!"
    sudo cp env.example /srv/selfhost/ddns/env
    sudo chmod 600 /srv/selfhost/ddns/env
fi

sudo chown -R nobody:nogroup /srv/selfhost/ddns
sudo chmod 755 /srv/selfhost/ddns
sudo chmod 755 /srv/selfhost/ddns/ddns
sudo chmod 600 /srv/selfhost/ddns/env

echo "Reloading systemd..."
sudo systemctl daemon-reload
sudo systemctl enable ddns.timer
sudo systemctl restart ddns.timer

echo ""
echo "✓ DDNS installed and timer started"
echo ""
echo "Commands:"
echo "  sudo systemctl status ddns.timer    # Check timer status"
echo "  sudo systemctl list-timers ddns.*   # Show next run time"
echo "  sudo journalctl -u ddns -f          # Watch logs"
echo "  sudo systemctl start ddns           # Run now (manual)"
echo ""
echo "⚠ Edit /srv/selfhost/ddns/env with your Gandi API token!"
