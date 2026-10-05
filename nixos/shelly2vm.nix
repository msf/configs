# shelly2vm — scrapes the Shelly devices on the local network into
# VictoriaMetrics on hopper. Source of truth: github.com/msf/selfhost,
# iot/sensors/shelly2vm. Bump rev + hash to deploy a new version.
{ lib, pkgs, ... }:

let
  shelly2vm = pkgs.buildGoModule {
    pname = "shelly2vm";
    version = "0-unstable-2026-09-02";

    src = pkgs.fetchFromGitHub {
      owner = "msf";
      repo = "selfhost";
      rev = "b3db243945eb05bb782e1af7294e09a275d43c06";
      hash = "sha256-R0nU8v1qSWz9UUV+LxIVehLBuK59KyTrQUuKbHWuSeU=";
    };

    modRoot = "iot/sensors/shelly2vm";
    vendorHash = null; # stdlib only, no dependencies to vendor
  };
in
{
  # Wake duration is variable: measured at ~57 s once and under ~10 s another
  # time. Poll at 1 s -- a missed wake costs two hours of readings, and probing
  # an absent host is cheap.
  # The H&T is a DHCP client that deep-sleeps, so it is only briefly on the
  # network and its lease has already floated once (.102 -> .140), silently
  # costing three days of readings. Pin it with a DHCP reservation on the
  # router, or this recurs. Enabling avahi + nss-mdns here would let the
  # device be addressed as shellyhtg3-e4b3232d4bd0.local instead.
  systemd.services.shelly2vm = {
    description = "Shelly to VictoriaMetrics scraper";
    # time-sync.target matters as much as the network here: this box has come up
    # with an unset RTC (boot recorded as 2001-01-01). Pushing samples before
    # NTP corrects the clock would write far-past timestamps into VictoriaMetrics,
    # which is not cleanly reversible.
    after = [ "network-online.target" "time-sync.target" ];
    wants = [ "network-online.target" "time-sync.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = lib.concatStringsSep " " [
        "${shelly2vm}/bin/shelly2vm"
        "-vm-host hopper"
        "-devices deposito=192.168.0.3,caldeira=192.168.0.103"
        "-sleepy sensor=192.168.0.140"
        "-sleepy-interval 1s"
      ];

      Restart = "on-failure";
      RestartSec = "10s";

      DynamicUser = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
      SystemCallFilter = [ "@system-service" ];
      MemoryMax = "64M";
    };
  };
}
