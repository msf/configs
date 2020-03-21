# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.grub.device = "/dev/sda";
  boot.supportedFilesystems = [ "btrfs" ];

  # Select internationalisation properties.
  i18n = {
    consoleFont = "Lat2-Terminus16";
    consoleKeyMap = "us";
    defaultLocale = "en_US.UTF-8";
  };

  # Set your time zone.
  time.timeZone = "UTC";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment = {
     variables = {
       EDITOR = "vim";
     };
     systemPackages = with pkgs; [
       atop
       btrfs-progs
       dstat
       file
       firefox
       gcc
       git
       gnumake
       go
       google-chrome
       htop
       iotop
       lm_sensors
       lsof
       meld
       ncdu
       powertop
       python3
       restic
       rxvt_unicode
       smartmontools
       sysstat
       tmux
       tree
       unzip
       vim
       weechat
       wget
       zsh
       zstd
     ];
   pathsToLink = [ "/libexec" ];
  };

  powerManagement.cpuFreqGovernor = "performance";

  users.defaultUserShell = pkgs.zsh;
  programs.zsh.enable = true;

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
  services.openssh.enable = true;
  services.openssh.permitRootLogin = "no";
  services.timesyncd.enable = true;

  networking.hostName = "acer4810"; # Define your hostname.
  networking.networkmanager.enable = true;
  networking.wireless.enable = false;  # Enables wireless support via wpa_supplicant.
  networking.wireless.networks = {
    "cabovisao-36A4" = {
       psk = "2c3996fc36a4";
    };
  };

  services.syncthing = {
    enable = true;
    user = "miguel";
    dataDir = "/home/miguel/";
    openDefaultPorts = true;
    systemService = true;
  };

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;
    layout = "us";
    videoDrivers = [ "intel" ];
    libinput.enable = true;  # Enable touchpad support.
    xkbOptions = "eurosign:e ctrl:nocaps";

    desktopManager = {
        default = "none";
        xterm.enable = false;
    };

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


  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.enp1s0.useDHCP = true;
  networking.interfaces.wlp2s0.useDHCP = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 22 ];
  networking.firewall.allowPing = true;
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
  networking.nameservers = [ "1.1.1.1" "8.8.8.8"];

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.miguel = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ]; # Enable ‘sudo’ for the user.
    shell = "/run/current-system/sw/bin/zsh";
  };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "19.09"; # Did you read the comment?

  nixpkgs.config.allowUnfree = true;
}
