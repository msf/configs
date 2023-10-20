# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, options, ... }:

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
    "mitigations=off"  # old b0x, need moar sp33d
  ];
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernel.sysctl."vm.swapiness" = 30;

  networking.hostName = "hopper"; # Define your hostname.
  networking.hostId = "a7ec8faa"; # zfs needs this
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Set your time zone.
  time.timeZone = "UTC";

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  #networking.useDHCP = false;
  networking.interfaces.eno1.useDHCP = true;
  #networking.interfaces.wlp3s0.useDHCP = true;
  networking.interfaces.eno1.ipv4.addresses = [
  {
    address = "192.168.0.14";
    prefixLength = 16;
  }
  ];

  networking.nameservers = [ "8.8.8.8" "1.1.1.1"];

  networking.extraHosts =
  ''
  100.119.216.56  grace-tail
  100.67.77.31    margie-tail
  100.77.156.119  kamala-tail
  100.92.53.58    hopper-tail
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
       go
       hdparm
       htop
       iotop
       keychain
       lm_sensors
       lshw
       lsof
       lxappearance
       mbuffer
       ncdu
       parted
       pciutils
       podman
       powertop
       python3
       rclone
       restic
       rxvt_unicode
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
       zsh
       zstd
     ];
   pathsToLink = [ "/libexec" ];
  };

  powerManagement.cpuFreqGovernor = "performance";

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

  # Enable the X11 windowing system.
  services.xserver = {
    enable = false;
    layout = "us";
    xkbOptions = "eurosign:e ctrl:nocaps";

    displayManager.defaultSession = "none+i3";

    windowManager.i3 = {
        enable = false;
        extraPackages = with pkgs; [
            dmenu
            i3status
            i3lock
            i3blocks
        ];
    };
  };


  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  programs.zsh.ohMyZsh = {
    enable = true;
    plugins = [ "git" "python" "man" "docker" "golang" "kubectl" ];
    theme = "agnoster";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.miguel = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker"]; # Enable ‘sudo’ for the user.
    uid = 1000;
    shell = "/run/current-system/sw/bin/zsh";
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIeH/MddmSVsqKwTR8ys07HMW/DDDAYdsm9/lYM6hd1X miguel.filipe@2020" "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDCZsY3qNOZP4uL+baYJ+B2lc6SEYWnJeKKPhwZ7azhO/RleAb3SsZ7452ktvCY1YE2fAsHwgHYrZEAXj8sD1DoDUMUWael2MAAzTdnPJWriINO5QeZ1WrSLaFHb5eQ4fUMpidCmFOnEWOl9MUopeTrOgLElKoAaq9mWQvBo3VtRXH4bk4/dkCWhYuI8rpXk9w+oNhTgFr9NumSnRIFDwKazNwZFjNxt0actwKanebg7lDQabTCGc3CuU59YGiYjQmgBpvb7mkQJi5grGdCg0uFeee2NlsSBUmmxBG+OLgrtjFXpbcm2H3IgBxQRRUnN2dho2sZW2c7tV4queKmSVsEtyEQcSpc5NQZrIFE6tVEeXHhfxFtGe2qmEgX6Zmh+/TgrGTJWocsQvvuRaCrJ5jTQkYHl/9rgIoSBc5NtUL/duVlA4DzvUOUsjDyU00WaTAHB0pm767ZICyN+7Zkb3o934+hreYzMszvL60sit1V4y8ORLplUJvGhkNHrljOrtp2VVtluWEPxJLENbiiUMDB6PqQI8c4vEx4BVvFeWaPJcAZLc2y9ZX5w8R6fl2f5VWXiGbjJl4xfTquSWa3YbC//x12KFyOvMzQCctCX6fgvgEg9oGig9Xg3fEoN/R26JBjbKbCeZI5UWSIOZrrTEo50icUsUR6AweIVQ1q2IV5NQ== miguel.filipe@gmail.com" ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?
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
          hostname = "hopper"
          omit_hostname = false
        [[outputs.influxdb_v2]]
          urls = ["http://grace-tail:8086"]
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

  # This is required by podman to run containers in rootless mode.
  security.unprivilegedUsernsClone = config.virtualisation.containers.enable;

  virtualisation = {
    podman = {
      enable = true;
      extraPackages = [ pkgs.zfs ];
      dockerCompat = true;
    };
    oci-containers = {
      backend = "podman";
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
            INFLUXHOST = "grace-tail";
            KOSTALHOST = "192.168.0.11";
          };
        };
      };
    };
  };


  # Enable cron backups
  services.cron = {
    enable = false;
    systemCronJobs = [
      # everynight, sync to alfeizerao
      #"0 1 * * *      root    /root/sync-alfeizerao.sh >> /tmp/sync-alfeizerao.log"
    ];
  };
}
