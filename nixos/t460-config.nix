# ThinkPad T460 in Alfeizerao (formerly "pompom", Debian). Family GNOME
# laptop that also takes over margiehamilton's energy scrapers.

{ pkgs, ... }:

let
  miguelKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIeH/MddmSVsqKwTR8ys07HMW/DDDAYdsm9/lYM6hd1X miguel.filipe@2020" "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDCZsY3qNOZP4uL+baYJ+B2lc6SEYWnJeKKPhwZ7azhO/RleAb3SsZ7452ktvCY1YE2fAsHwgHYrZEAXj8sD1DoDUMUWael2MAAzTdnPJWriINO5QeZ1WrSLaFHb5eQ4fUMpidCmFOnEWOl9MUopeTrOgLElKoAaq9mWQvBo3VtRXH4bk4/dkCWhYuI8rpXk9w+oNhTgFr9NumSnRIFDwKazNwZFjNxt0actwKanebg7lDQabTCGc3CuU59YGiYjQmgBpvb7mkQJi5grGdCg0uFeee2NlsSBUmmxBG+OLgrtjFXpbcm2H3IgBxQRRUnN2dho2sZW2c7tV4queKmSVsEtyEQcSpc5NQZrIFE6tVEeXHhfxFtGe2qmEgX6Zmh+/TgrGTJWocsQvvuRaCrJ5jTQkYHl/9rgIoSBc5NtUL/duVlA4DzvUOUsjDyU00WaTAHB0pm767ZICyN+7Zkb3o934+hreYzMszvL60sit1V4y8ORLplUJvGhkNHrljOrtp2VVtluWEPxJLENbiiUMDB6PqQI8c4vEx4BVvFeWaPJcAZLc2y9ZX5w8R6fl2f5VWXiGbjJl4xfTquSWa3YbC//x12KFyOvMzQCctCX6fgvgEg9oGig9Xg3fEoN/R26JBjbKbCeZI5UWSIOZrrTEo50icUsUR6AweIVQ1q2IV5NQ== miguel.filipe@gmail.com" ];

  # UIDs/GIDs match the Debian install so the reused /home keeps its ownership.
  familyUser = name: uid: {
    inherit uid;
    isNormalUser = true;
    group = name;
    extraGroups = [ "users" "networkmanager" "audio" "video" ];
    shell = pkgs.bashInteractive;
  };
in
{
  imports = [ ./t460-hw-config.nix ./shelly2vm.nix ];

  boot.loader.systemd-boot.enable = true;
  # The ESP is only 512M and also holds the kernels.
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;
  # Remote box: a boot-time panic should reboot (back to the BootOrder default)
  # instead of waiting for someone on site.
  boot.kernelParams = [ "panic=30" ];

  time.timeZone = "Europe/Lisbon";
  networking.nameservers = [ "8.8.8.8" "1.1.1.1" ];

  networking.firewall.enable = false;

  i18n.defaultLocale = "en_US.UTF-8";
  console.useXkbConfig = true;
  services.xserver.xkb = {
    layout = "gb";
    model = "pc105";
  };

  environment = {
    variables.EDITOR = "vim";
    systemPackages = with pkgs; [
      atop
      dool
      (runCommand "dstat" { } ''
        mkdir -p "$out/bin"
        ln -s "${dool}/bin/dool" "$out/bin/dstat"
      '')
      delta
      efibootmgr
      file
      gcc
      ghostty.terminfo
      git
      gnumake
      go
      htop
      iotop
      lm_sensors
      lshw
      lsof
      ncdu
      neovim
      parted
      pciutils
      powertop
      psmisc
      python3
      rclone
      restic
      smartmontools
      sysstat
      tmux
      tree
      unzip
      vim
      wget
      zsh
      zstd
    ];
  };

  users.defaultUserShell = pkgs.zsh;
  programs.zsh.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  services.timesyncd.enable = true;
  services.fwupd.enable = true;
  services.tailscale.enable = true;
  services.printing.enable = true;

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  programs.firefox.enable = true;

  # Never suspend or hibernate: the box runs the energy scrapers and is
  # managed remotely, lid closed or not.
  services.displayManager.gdm.autoSuspend = false;
  services.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.settings-daemon.plugins.power]
    sleep-inactive-ac-type='nothing'
    sleep-inactive-battery-type='nothing'
  '';
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleSuspendKey = "ignore";
    HandleHibernateKey = "ignore";
  };
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  users.users.root.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMi8xVr7C/qB+DGIGa07Hm9uv0pTKZ8qbX8DywAteaXP root@hopper" ];
  users.groups = {
    miguel.gid = 1000;
    sofia.gid = 1001;
    luisa.gid = 1002;
    caitlin.gid = 1003;
  };
  users.users.miguel = {
    isNormalUser = true;
    uid = 1000;
    group = "miguel";
    extraGroups = [ "users" "wheel" "networkmanager" "audio" "video" ];
    shell = "/run/current-system/sw/bin/zsh";
    openssh.authorizedKeys.keys = miguelKeys;
  };
  users.users.sofia = familyUser "sofia" 1001;
  users.users.luisa = familyUser "luisa" 1002;
  users.users.caitlin = familyUser "caitlin" 1003;

  # Remote, non-interactive administration over ssh (no root shell otherwise).
  security.sudo.extraRules = [
    {
      users = [ "miguel" ];
      commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ];
    }
  ];

  system.stateVersion = "26.05"; # Did you read the comment?
  system.autoUpgrade.enable = false;

  nix.gc = {
    automatic = true;
    dates = "weekly UTC";
    options = "--delete-older-than 14d";
  };

  nixpkgs.config.allowUnfree = true;

  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true;
    };
    oci-containers = {
      backend = "podman";
      containers = {
        kostal2influx = {
          image = "ghcr.io/msf/kostal2influx:v0.9";
          user = "nobody:nogroup";
          # Podman snapshots resolv.conf at container start, which at boot is
          # before Tailscale's MagicDNS is up, so "hopper" never resolves.
          extraOptions = [ "--network=host" "--add-host=hopper:100.119.216.56" ];
          environment = {
            VM_HOST = "hopper";
          };
        };
      };
    };
  };
}
