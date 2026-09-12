# SwayOSD

Sway starts `swayosd-server`. Brightness and volume bindings use 5% steps; volume is capped at 120%. Speaker and microphone mute also show feedback.

The system libinput backend reads raw keys before Sway remaps Caps Lock to Control. Install its configuration separately:

```zsh
sudo apt install swayosd
sudo install -o root -g root -m 0644 ~/configs/sway/swayosd/backend.toml /etc/xdg/swayosd/backend.toml
sudo systemctl restart swayosd-libinput-backend.service
```

Start a new Sway session to launch the OSD server. Brightness and volume keys must show an indicator; Caps Lock must not.
