# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;
  };

  boot.supportedFilesystems = [ "zfs" "btrfs" ];
  boot.zfs.enableUnstable = true;
  boot.kernelParams = [
    "zfs.zfs_arc_max=3221225472"  # 3GB
    "mitigations=off"  # old b0x, need moar sp33d
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernel.sysctl."vm.swapiness" = 60;

  # premature to enable this..
  #zramSwap = {
  #  enable = true;
  #  memoryPercent = 20;
  #  numDevices = 1;
  #  algorithm = "zstd";
  #};

  networking.hostId = "b05e6b14";  # for ZFS
  networking.hostName = "margiehamilton"; # Define your hostname.
  networking.networkmanager.enable = true;
  networking.wireless.enable = false;  # using network manager

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.enp2s0f0.useDHCP = true;

  networking.nameservers = [ "8.8.8.8" "1.1.1.1"];

  networking.extraHosts =
  ''
  100.119.38.108  hopper-tail
  100.89.241.6    acer-tail
  100.99.150.19   lovelace-tail
  100.67.77.31    margie-tail
  100.121.57.66   curie-tail
  '';

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Open ports in the firewall.
  # syncthing -> 22000,21027
  networking.firewall.allowedTCPPorts = [ 22  5001 22000 21027];
  networking.firewall.allowedUDPPorts = [ 5001 5002 22000 21027];
  networking.firewall.allowPing = true;
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  # Select internationalisation properties.
  console.useXkbConfig = true;
  i18n = {
    defaultLocale = "en_US.UTF-8";
  };

  # Set your time zone.
  time.timeZone = "UTC";

  # List packages installed in system profile. To search, run:
  environment = {
     variables = {
       EDITOR = "vim";
     };
     systemPackages = with pkgs; [
       atop
       awscli
       btrfs-progs
       docker
       dstat
       file
       firefox
       fwupd
       gcc
       git
       gnumake
       gnome3.adwaita-icon-theme
       gnome3.gnome-power-manager
       go
       hdparm
       google-chrome
       htop
       iotop
       lm_sensors
       lshw
       lsof
       lxappearance
       ncdu
       parted
       pciutils
       podman
       powertop
       python3
       rclone
       restic
       rxvt_unicode
       smartmontools
       syncthing
       sysstat
       syncthing
       sysstat
       tmux
       tree
       unzip
       vim
       weechat
       wget
       zoom-us
       zfstools
       zsh
       zstd
     ];
   pathsToLink = [ "/libexec" ];
  };

  powerManagement.cpuFreqGovernor = "performance";

  users.defaultUserShell = pkgs.zsh;
  programs.zsh.enable = true;
  programs.dconf.enable = true; #gnome

  security.pam.loginLimits = [{
    domain = "*";
    type = "hard";
    item = "nofile";
    value = "65535";
  }];

  fonts = {
    enableFontDir = true;
    enableGhostscriptFonts = true;
    fonts = with pkgs; [
      google-fonts
      inconsolata
      liberation_ttf
      powerline-fonts
      source-code-pro
      terminus_font
      ttf_bitstream_vera
      ubuntu_font_family
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
	permitRootLogin = "prohibit-password";
	passwordAuthentication = false;
  };
  users.users.root.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMi8xVr7C/qB+DGIGa07Hm9uv0pTKZ8qbX8DywAteaXP miguel@curie" ];

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
    enable = true;
    user = "miguel";
    dataDir = "/media/simple/syncthing/";
    configDir = "/home/miguel/.config/syncthing";
    openDefaultPorts = true;
    systemService = true;
  };

  services.fwupd.enable = true;
  services.tailscale.enable = true;

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;
    layout = "us";
    videoDrivers = [ "intel" ];
    libinput.enable = true;  # Enable touchpad support.
    xkbOptions = "eurosign:e ctrl:nocaps";

    displayManager.defaultSession = "none+i3";
   desktopManager.gnome3.enable = true;
#    displayManager.gdm.enable = true;
#    displayManager.gdm.wayland = false;

    windowManager.i3 = {
        enable = true;
        # package = pkgs.i3-gaps;
        extraPackages = with pkgs; [
            dmenu
            i3status
            i3lock
            i3blocks
            feh
        ];
    };
  };
  services.dbus.packages = with pkgs; [ gnome3.dconf gnome2.GConf ];  # needed for gtk apps
  services.udev.packages = with pkgs; [ gnome3.gnome-settings-daemon ]; # gnome


  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.miguel = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ]; # Enable ‘sudo’ for the user.
    uid = 1000;
    shell = "/run/current-system/sw/bin/zsh";
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIeH/MddmSVsqKwTR8ys07HMW/DDDAYdsm9/lYM6hd1X miguel.filipe@unbabel" "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDCZsY3qNOZP4uL+baYJ+B2lc6SEYWnJeKKPhwZ7azhO/RleAb3SsZ7452ktvCY1YE2fAsHwgHYrZEAXj8sD1DoDUMUWael2MAAzTdnPJWriINO5QeZ1WrSLaFHb5eQ4fUMpidCmFOnEWOl9MUopeTrOgLElKoAaq9mWQvBo3VtRXH4bk4/dkCWhYuI8rpXk9w+oNhTgFr9NumSnRIFDwKazNwZFjNxt0actwKanebg7lDQabTCGc3CuU59YGiYjQmgBpvb7mkQJi5grGdCg0uFeee2NlsSBUmmxBG+OLgrtjFXpbcm2H3IgBxQRRUnN2dho2sZW2c7tV4queKmSVsEtyEQcSpc5NQZrIFE6tVEeXHhfxFtGe2qmEgX6Zmh+/TgrGTJWocsQvvuRaCrJ5jTQkYHl/9rgIoSBc5NtUL/duVlA4DzvUOUsjDyU00WaTAHB0pm767ZICyN+7Zkb3o934+hreYzMszvL60sit1V4y8ORLplUJvGhkNHrljOrtp2VVtluWEPxJLENbiiUMDB6PqQI8c4vEx4BVvFeWaPJcAZLc2y9ZX5w8R6fl2f5VWXiGbjJl4xfTquSWa3YbC//x12KFyOvMzQCctCX6fgvgEg9oGig9Xg3fEoN/R26JBjbKbCeZI5UWSIOZrrTEo50icUsUR6AweIVQ1q2IV5NQ== miguel.filipe@gmail.com" ];
  };
  users.users.sofia = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" ]; # Enable ‘sudo’ for the user.
    shell = "/run/current-system/sw/bin/zsh";
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIeH/MddmSVsqKwTR8ys07HMW/DDDAYdsm9/lYM6hd1X miguel.filipe@unbabel" "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDCZsY3qNOZP4uL+baYJ+B2lc6SEYWnJeKKPhwZ7azhO/RleAb3SsZ7452ktvCY1YE2fAsHwgHYrZEAXj8sD1DoDUMUWael2MAAzTdnPJWriINO5QeZ1WrSLaFHb5eQ4fUMpidCmFOnEWOl9MUopeTrOgLElKoAaq9mWQvBo3VtRXH4bk4/dkCWhYuI8rpXk9w+oNhTgFr9NumSnRIFDwKazNwZFjNxt0actwKanebg7lDQabTCGc3CuU59YGiYjQmgBpvb7mkQJi5grGdCg0uFeee2NlsSBUmmxBG+OLgrtjFXpbcm2H3IgBxQRRUnN2dho2sZW2c7tV4queKmSVsEtyEQcSpc5NQZrIFE6tVEeXHhfxFtGe2qmEgX6Zmh+/TgrGTJWocsQvvuRaCrJ5jTQkYHl/9rgIoSBc5NtUL/duVlA4DzvUOUsjDyU00WaTAHB0pm767ZICyN+7Zkb3o934+hreYzMszvL60sit1V4y8ORLplUJvGhkNHrljOrtp2VVtluWEPxJLENbiiUMDB6PqQI8c4vEx4BVvFeWaPJcAZLc2y9ZX5w8R6fl2f5VWXiGbjJl4xfTquSWa3YbC//x12KFyOvMzQCctCX6fgvgEg9oGig9Xg3fEoN/R26JBjbKbCeZI5UWSIOZrrTEo50icUsUR6AweIVQ1q2IV5NQ== miguel.filipe@gmail.com" ];
  };
  users.users.notroot = {
    isNormalUser = true;
  };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "20.09"; # Did you read the comment?
  system.autoUpgrade.enable = true;  # incremental updates are good
  system.autoUpgrade.allowReboot = false;  # not that crazy

  # Clean up packages after a while
  nix.gc = {
    automatic = true;
    dates = "weekly UTC";
  };

  nixpkgs.config.allowUnfree = true;

  # servers/services inside containers
  environment.etc = {
    "telegraf/telegraf.conf" = {
      mode = "0440";
      text = ''
        [global_tags]
        [agent]
          interval = "10s"
          round_interval = true
          metric_batch_size = 1000
          metric_buffer_limit = 10000
          collection_jitter = "0s"
          flush_interval = "10s"
          flush_jitter = "0s"
          precision = ""
          hostname = "margie"
          omit_hostname = false
        [[outputs.influxdb_v2]]
          urls = ["http://hopper-tail:8086"]
	  token = "6fm31K9UVWC2o0oADBWg_broHVpdV9egDoj51mMGy-pYvRNAPBB475qjWRTb-8N66mTOsXbeQcM8YVvzwxrLNw=="
          organization = "casa"
          bucket = "alfeizerao"
        [[inputs.cpu]]
          percpu = true
          totalcpu = true
          collect_cpu_time = false
          report_active = false
        [[inputs.disk]]
          ignore_fs = ["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]
        [[inputs.diskio]]
        [[inputs.kernel]]
        [[inputs.mem]]
        [[inputs.processes]]
        [[inputs.swap]]
        [[inputs.system]]
        [[inputs.zfs]]
          poolMetrics = true
        [[inputs.sensors]]
      '';
    };
  };

  virtualisation = {
    podman = {
      enable = true;
      extraPackages = [ pkgs.zfs ];
    };
    docker = {
      enable = true;
    };
    oci-containers = {
      backend = "docker";
      containers = {
        telegraf = {
          image = "telegraf:1.17-alpine";
          extraOptions = ["--network=host"];
          volumes = [
             "/:/hostfs:ro"
             "/etc:/hostfs/etc:ro"
             "/proc:/hostfs/proc:ro"
             "/sys:/hostfs/sys:ro"
             "/var/run/utmp:/var/run/utmp:ro"
             "/etc/telegraf/telegraf.conf:/etc/telegraf/telegraf.conf:ro"
          ];
	  environment = {
	    HOST_ETC = "/hostfs/etc";
	    HOST_PROC = "/hostfs/proc";
	    HOST_SYS = "/hostfs/sys";
	    HOST_MOUNT_PREFIX = "/hostfs";
	  };
        };
         kostal2influx = {
          image = "quay.io/msf/kostal2influx:v0.2";
          user = "nobody:nogroup";
          extraOptions = ["--network=host"];
	  environment = {
	    INFLUXTOKEN = "6fm31K9UVWC2o0oADBWg_broHVpdV9egDoj51mMGy-pYvRNAPBB475qjWRTb-8N66mTOsXbeQcM8YVvzwxrLNw==";
            INFLUXHOST = "hopper-tail";
            KOSTALHOST = "192.168.0.11";
	  };
        };
      };
    };
  };
}
