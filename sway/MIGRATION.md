# Regolith → vanilla sway migration

Work log. Started 2026-06-09, trial validated 2026-06-10.
Related: `~/.config/regolith3/DISPLAY_WAKE_TROUBLESHOOTING.md` (the lock/wake
saga that motivated this).

## Why

Six years on Regolith, but every recurring failure traced to its glue, not
sway: regolith-powerd (gtklock/swayidle DPMS deadlock, 46 of 47 logged
black-screen incidents), regolith-displayd (rewrites kanshi profiles keyed on
broken `Unknown Unknown Unknown` EDID identity, zombie kanshi children),
trawld/Xresources indirection (`regolith-look refresh` does NOT reload
Xresources; only `trawldb --merge` does). Most components were already
replaced piecemeal over time (mako, fuzzel, grim/slurp, i3status-rust config,
kanshi profiles, swaylock). This migration evicts the rest.

## New home

- `~/.config/sway/config` — standalone, no trawl/Xresources, literal values.
  Keybinding comments keep the remontoire schema
  (`## Category // Action // Binding ##`) so the shortcut viewer works.
- `~/.local/bin/sway-shortcuts` — Meta+Shift+? viewer (parses the schema,
  shows in fuzzel). Replaces ilia/remontoire.
- `~/.config/fuzzel/fuzzel.ini` — launcher: ayu-mirage colors, Arc icon theme.
- `~/.config/xdg-desktop-portal/sway-portals.conf` — REQUIRED. Without it no
  Settings/FileChooser portal backend matches a `sway` desktop and every GTK
  app stalls ~20s at launch (this was the "slow startup, feels broken"
  symptom in the first trials). gtk default + wlr for screenshot/screencast.
- `~/.config/swaylock/config` — lock screen (see wake-troubleshooting doc).
- Reused unchanged: `~/.config/regolith3/i3status-rust/config.toml` (bar),
  `~/.config/regolith3/kanshi/config` + profiles, `~/.config/mako/config`,
  `~/bin/fw13-*` power scripts, `~/bin/display-recover`.

## Binding decisions (deltas from Regolith defaults)

- Meta+D → wdisplays (display GUI; nwg-displays once on 26.04).
- Meta+S → `gnome-control-center sound` (works without GNOME shell; has
  device dropdowns + speaker test; pavucontrol is the fallback). Was unbound.
- Print → region screenshot (grimshot savecopy), restoring the lost
  screenshot-key config; Ctrl+Shift+3 unchanged.
- Compose key: `compose:ralt` (AltGr then `,c`→ç `'a`→á `~a`→ã). Was lost
  config under Regolith.
- Dropped as unused: clamshell, childe (Meta+`), layout cycling
  (Meta+Alt+Backspace), file search (Meta+Alt+Space), reboot/shutdown binds,
  Meta+W/B panels (use Meta+D), regolith-control-center, ilia.
- Kept verbatim: workspaces/move/carry, hjkl, Meta+T/Shift+T/F/Shift+F,
  scratchpad, resize mode, Meta+Esc lock, Meta+Shift+E exit (swaynag).

## Trial findings and fixes

1. GTK apps slow to launch → portal config (above). Root cause confirmed via
   `UseIn=` in /usr/share/xdg-desktop-portal/portals/*.portal: only wlr
   matches "sway" and it lacks Settings.
2. ghostty windows opened in the *other* session → GTK single-instance; fixed
   with `--gtk-single-instance=false` in the terminal binding.
3. Cursor late to appear → explicit `seat seat0 xcursor_theme Adwaita 24`.
4. Fonts: Regolith look uses Hack Nerd Font Mono 12; bar set to 11 by taste.
5. Theming approach (no tooling, no ricing): one canonical palette =
   ayu-mirage hexes from /usr/share/regolith-look/ayu-mirage/root, applied
   manually to the five configs (sway client+bar colors, fuzzel, swaylock,
   mako). Palette reference lives in the sway config comments.
6. LG EW/WQHD monitor is slow to sync on startup; possibly amplified by
   double modeset (sway default → kanshi profile). If it annoys: put the dock
   layout as static `output` rules in sway config, keep kanshi for hotplug
   only. Not yet done; measure first.

## How to run

Trial: TTY login → `sway` (binary is sway-regolith's /usr/bin/sway 1.9;
upstream `sway` package conflicts with it — fine, same compositor).
Exit: Meta+Shift+E. Reload config: Meta+Shift+C (portals/exec lines need a
full session restart).

## Jun 11-12 2026: wake failure root-caused; regolith glue neutralized

Two more black-screen incidents (Jun 11 14:03, Jun 12 09:43) in the new
session: outputs `power: false`, swaylock healthy, swayidle alive, but the
`resume → power on` handler never ran. Root cause: **sway-audio-idle-inhibit**
(regolith package unit, auto-started because the GDM session pulls
`graphical-session.target`) toggling the wlroots idle inhibitor on browser
audio. wlroots 0.17.1 `notify_activity()` returns early while inhibited —
real keypresses are invisible to swayidle, so resume never fires. Full
write-up: `~/.config/regolith3/DISPLAY_WAKE_TROUBLESHOOTING.md`.

Mutations applied (Jun 12):

- Masked in user scope (they are *globally* enabled by the packages, plain
  disable does not stick): `sway-audio-idle-inhibit.service`,
  `regolith-init-powerd.service`, `regolith-init-displayd.service`,
  `regolith-init-inputd.service` → symlinks to /dev/null in
  `~/.config/systemd/user/`.
- Removed regolith apt sources (`/etc/apt/sources.list.d/regolith.list*`,
  done by hand). Keyring left in place. **Packages NOT removed**:
  `sway-regolith` owns `/usr/bin/sway`, so purging waits for the upstream
  `sway` package swap at 26.04 time.
- swayidle now runs via `~/.local/bin/swayidle-run`, logging every
  timeout/resume to `~/.local/state/swayidle.log` (incident classification).
- `bindsym --locked $mod+Shift+o` → `output * power on`: keyboard wake
  rescue; bindings work even when idle-notify drops input. No more SSH for
  this failure mode.
- Static `output` rules added for the current dock combo (LG 0,0; eDP-1
  scale 1.5 at 757,1440 — the T layout, laptop centered under the LG).
  Rules for absent outputs are inert, so laptop-only travel is unaffected;
  eDP-1 refresh stays kanshi-owned (60 vs 120Hz is topology-dependent).
- Reload binding is now `reload; exec pkill -HUP -x kanshi` — a bare
  `swaymsg reload` resets outputs to config defaults and kanshi gets no
  event for it (this bit us: lost DPI + arrangement).
- kanshi LG profile position aligned to the live layout (945→757).
- Reminder: with regolith-displayd gone, **nothing persists display changes**;
  kanshi profile files are hand-edited and the single source of truth.

## Known gaps

- **No OSD/visual feedback for volume, brightness, mute, or media keys.**
  Trialed `wob` (only OSD packaged in noble) on Jun 12; reverted same day —
  v0.14 too crude (no named styles, FIFO plumbing fiddly). Decision: live
  without OSD until 26.04, then adopt **swayosd** (also covers play/pause/
  media-key feedback). `wob` package can be apt-removed.
- Browser video/audio cannot inhibit idle: nothing owns
  `org.freedesktop.ScreenSaver` in this session (journal shows failing
  portal calls), and the audio-based inhibitor was the wake-killer and is
  gone. Screens will lock during video. Revisit deliberately (swayidle
  inhibit bridge or swayosd-adjacent tooling) — do NOT resurrect
  sway-audio-idle-inhibit.

## Remaining roadmap

1. ~~Live in the trial session; watch for wake/lock regressions~~ — done,
   regression found and root-caused (see above).
2. ~~Stop regolith-init-* user services from starting.~~ — done (masked).
3. Purge regolith packages (apt sources already removed); swap
   `sway-regolith` → upstream `sway` at purge time. Check first what owns
   themes/looks still in use (user suspects some regolith theme assets).
4. `do-release-upgrade` to Ubuntu 26.04. Then: **swayosd** (OSD gap),
   nwg-displays, pwvucontrol candidates.
5. Optional someday: trial niri as a parallel session.
