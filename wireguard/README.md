sudo cp reresolve-dns.service  /etc/systemd/system/wireguard-reresolve-dns.service
sudo cp reresolve-dns.timer    /etc/systemd/system/wireguard-reresolve-dns.timer

sudo systemctl enable --now /etc/systemd/system/wireguard-reresolve-dns.timer
