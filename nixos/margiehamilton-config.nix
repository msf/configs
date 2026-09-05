# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ pkgs, options, ... }:

{
  imports = [ ./margiehamilton-hw-config.nix ./margiehamilton-shelly2vm.nix ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "UTC";
  networking.nameservers = [ "8.8.8.8" "1.1.1.1" ];

  networking.extraHosts =
  ''
  100.119.216.56  hopper-tail
  100.67.77.31    margie-tail
  100.77.156.119  kamala-tail
  100.93.239.53   curie-tail
  100.94.188.127  lovelace-tail
  '';

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Open ports in the firewall.
  # syncthing -> 22000,21027
  networking.firewall.allowedTCPPorts = [ 22  5001 22000 21027];
  networking.firewall.allowedUDPPorts = [ 5001 5002 22000 21027];
  networking.firewall.allowPing = true;
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
    # Adds terminus_font for people with HiDPI displays
    packages = options.console.packages.default ++ [ pkgs.terminus_font ];
  };

  # List packages installed in system profile. To search, run:
  environment = {
     variables = {
       EDITOR = "vim";
     };
     sessionVariables = {
       BROWSER = "firefox";
       MOZ_ENABLE_WAYLAND = "1";
     };
     systemPackages = with pkgs; [
       atop
       dool
       (runCommand "dstat" { } ''
         mkdir -p "$out/bin"
         ln -s "${dool}/bin/dool" "$out/bin/dstat"
       '')
       awscli
       btrfs-progs
       delta
       file
       fwupd
       gcc
       ghostty.terminfo
       git
       gnumake
       go
       hdparm
       htop
       iotop
       lm_sensors
       lshw
       lsof
       mbuffer
       ncdu
       neovim
       parted
       pciutils
       powertop
       python3
       rclone
       restic
       xterm
       sanoid
       smartmontools
       syncthing
       sysstat
       tmux
       tree
       unzip
       vim
       weechat
       wget
       zfstools
       #zoom-us
       zsh
       zstd
     ];
   pathsToLink = [ "/libexec" ];
  };

  powerManagement.cpuFreqGovernor = "schedutil";

  services.tlp = {
    enable = true;
    pd.enable = true;
    settings = {
      TLP_AUTO_SWITCH = 0;
      TLP_DEFAULT_MODE = "BAL";
      CPU_SCALING_GOVERNOR_ON_SAV = "schedutil";
    };
  };

  users.defaultUserShell = pkgs.zsh;
  programs.zsh.enable = true;

  security.pam.loginLimits = [
  {
    domain = "*";
    type = "hard";
    item = "nofile";
    value = "65535";
  }
  {
    domain = "*";
    type = "hard";
    item = "nproc";
    value = "1049600";
  }
  ];

  fonts = {
    fontDir.enable = true;
    enableGhostscriptFonts = true;
    packages = with pkgs; [
      google-fonts
      inconsolata
      liberation_ttf
      powerline-fonts
      source-code-pro
      terminus_font
      ttf_bitstream_vera
    ];
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = { enable = true; enableSSHSupport = true; };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };
  users.users.root.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMi8xVr7C/qB+DGIGa07Hm9uv0pTKZ8qbX8DywAteaXP root@hopper" ];

  services.timesyncd.enable = true;
  services.zfs.autoScrub.enable = true;
  services.zfs.autoSnapshot = {
    enable = true;
    monthly = 4;  # default is 12
    weekly = 4;
    daily = 4;  # default is 7
    hourly = 4; # default is 24
    frequent = 4;
  };

  services.syncthing = {
    enable = false;
    user = "miguel";
    dataDir = "/media/simple/syncthing/";
    configDir = "/home/miguel/.config/syncthing";
    openDefaultPorts = true;
    systemService = true;
  };

  services.fwupd.enable = true;
  services.tailscale.enable = true;

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraPackages = with pkgs; [
      alacritty
      brightnessctl
      grim
      i3status-rust
      pulseaudio
      swayidle
      swaylock
      wmenu
    ];
  };

  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd sway";
  };

  programs.firefox = {
    enable = true;
    policies.SearchEngines = {
      Default = "DuckDuckGo";
      DefaultPrivate = "DuckDuckGo";
    };
    preferences = {
      "media.av1.enabled" = false;
      "media.ffmpeg.vaapi.enabled" = true;
      "media.mediasource.vp9.enabled" = false;
    };
    preferencesStatus = "default";
  };


  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.miguel = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ]; # Enable ‘sudo’ for the user.
    uid = 1000;
    shell = "/run/current-system/sw/bin/zsh";
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIeH/MddmSVsqKwTR8ys07HMW/DDDAYdsm9/lYM6hd1X miguel.filipe@2020" "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDCZsY3qNOZP4uL+baYJ+B2lc6SEYWnJeKKPhwZ7azhO/RleAb3SsZ7452ktvCY1YE2fAsHwgHYrZEAXj8sD1DoDUMUWael2MAAzTdnPJWriINO5QeZ1WrSLaFHb5eQ4fUMpidCmFOnEWOl9MUopeTrOgLElKoAaq9mWQvBo3VtRXH4bk4/dkCWhYuI8rpXk9w+oNhTgFr9NumSnRIFDwKazNwZFjNxt0actwKanebg7lDQabTCGc3CuU59YGiYjQmgBpvb7mkQJi5grGdCg0uFeee2NlsSBUmmxBG+OLgrtjFXpbcm2H3IgBxQRRUnN2dho2sZW2c7tV4queKmSVsEtyEQcSpc5NQZrIFE6tVEeXHhfxFtGe2qmEgX6Zmh+/TgrGTJWocsQvvuRaCrJ5jTQkYHl/9rgIoSBc5NtUL/duVlA4DzvUOUsjDyU00WaTAHB0pm767ZICyN+7Zkb3o934+hreYzMszvL60sit1V4y8ORLplUJvGhkNHrljOrtp2VVtluWEPxJLENbiiUMDB6PqQI8c4vEx4BVvFeWaPJcAZLc2y9ZX5w8R6fl2f5VWXiGbjJl4xfTquSWa3YbC//x12KFyOvMzQCctCX6fgvgEg9oGig9Xg3fEoN/R26JBjbKbCeZI5UWSIOZrrTEo50icUsUR6AweIVQ1q2IV5NQ== miguel.filipe@gmail.com" ];
  };
  users.users.sofia = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" ]; # Enable ‘sudo’ for the user.
    shell = "/run/current-system/sw/bin/zsh";
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIeH/MddmSVsqKwTR8ys07HMW/DDDAYdsm9/lYM6hd1X miguel.filipe@2020" "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDCZsY3qNOZP4uL+baYJ+B2lc6SEYWnJeKKPhwZ7azhO/RleAb3SsZ7452ktvCY1YE2fAsHwgHYrZEAXj8sD1DoDUMUWael2MAAzTdnPJWriINO5QeZ1WrSLaFHb5eQ4fUMpidCmFOnEWOl9MUopeTrOgLElKoAaq9mWQvBo3VtRXH4bk4/dkCWhYuI8rpXk9w+oNhTgFr9NumSnRIFDwKazNwZFjNxt0actwKanebg7lDQabTCGc3CuU59YGiYjQmgBpvb7mkQJi5grGdCg0uFeee2NlsSBUmmxBG+OLgrtjFXpbcm2H3IgBxQRRUnN2dho2sZW2c7tV4queKmSVsEtyEQcSpc5NQZrIFE6tVEeXHhfxFtGe2qmEgX6Zmh+/TgrGTJWocsQvvuRaCrJ5jTQkYHl/9rgIoSBc5NtUL/duVlA4DzvUOUsjDyU00WaTAHB0pm767ZICyN+7Zkb3o934+hreYzMszvL60sit1V4y8ORLplUJvGhkNHrljOrtp2VVtluWEPxJLENbiiUMDB6PqQI8c4vEx4BVvFeWaPJcAZLc2y9ZX5w8R6fl2f5VWXiGbjJl4xfTquSWa3YbC//x12KFyOvMzQCctCX6fgvgEg9oGig9Xg3fEoN/R26JBjbKbCeZI5UWSIOZrrTEo50icUsUR6AweIVQ1q2IV5NQ== miguel.filipe@gmail.com" ];
  };
  users.users.notroot = {
    isNormalUser = true;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?
  system.autoUpgrade.enable = false; # Re-enable after the staged upgrade.

  # Clean up packages after a while
  nix.gc = {
    automatic = true;
    dates = "weekly UTC";
    options = "--delete-older-than 14d";
  };

  nixpkgs.config.allowUnfree = true;

  # servers/services inside containers
  environment.etc = {
    "i3status-rust/config.toml".text = ''
      [theme]
      theme = "native"

      [[block]]
      block = "custom"
      command = "${pkgs.tlp-pd}/bin/tlpctl get 2>/dev/null || echo unavailable"
      format = " PWR $text "
      interval = 5

      [[block]]
      block = "cpu"
      format = " CPU $utilization $frequency "
      format_alt = " CPU $barchart "
      interval = 5

      [[block]]
      block = "temperature"
      format = " TEMP $average "
      chip = "coretemp-isa-0000"
      inputs = ["Package id 0"]
      interval = 5

      [[block]]
      block = "memory"
      format = " MEM $mem_used_percents "
      interval = 10

      [[block]]
      block = "time"
      format = " $timestamp.datetime(f:'%a %F %R') "
      interval = 5
    '';
    "sway/config.d/power.conf".text = ''
      exec ${pkgs.swayidle}/bin/swayidle -w \
        timeout 1800 '${pkgs.sway}/bin/swaymsg "output * power off"' \
        resume '${pkgs.sway}/bin/swaymsg "output * power on"'

      bar bar-0 {
        status_command ${pkgs.i3status-rust}/bin/i3status-rs /etc/i3status-rust/config.toml
        font pango:monospace 10
        separator_symbol " | "
      }
    '';
    "sway/config.d/terminal.conf".text = ''
      bindsym $mod+Return exec alacritty
    '';
  };

  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true;
    };
    containers = {
      enable = true;
      storage.settings.storage = {
        driver = "vfs"; # ponytail: use overlay storage if image churn makes vfs materially slow.
        runroot = "/run/containers/storage";
        graphroot = "/var/lib/containers/storage";
      };
    };
    oci-containers = {
      backend = "podman";
      containers = {
        kostal2influx = {
          image = "ghcr.io/msf/kostal2influx:v0.9";
          user = "nobody:nogroup";
          extraOptions = ["--network=host"];
          environment = {
            VM_HOST = "hopper";
          };
        };
      };
    };
  };
}
