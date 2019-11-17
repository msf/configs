# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

let
  unstableTarball = 
    fetchTarball
      https://github.com/NixOS/nixpkgs-channels/archive/nixos-unstable.tar.gz;
in
{
  imports =
    [ # Include the results of the hardware scan.
      /etc/nixos/hardware-configuration.nix
    ];

  nixpkgs.config = {
    packageOverrides = pkgs: {
      unstable = import unstableTarball {
        config = config.nixpkgs.config;
      };
    };
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "btrfs" "zfs" ];
  boot.zfs.enableUnstable = true;

  networking.hostName = "hopper"; # Define your hostname.
  networking.hostId = "a7ec8faa"; # zfs needs this
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
   i18n = {
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
       wget
       vim
       zsh
       git
       tmux
       lsof
       htop
       dstat
       iotop
       smartmontools
       firefox
       python3
       gcc
       zstd
       btrfs-progs
       unstable.go
       weechat
       unstable.restic
       lm_sensors
       ncdu
       meld
       tree
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
    dataDir = "/home/miguel/";
    openDefaultPorts = true;
    systemService = true;
  };

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;
    layout = "us";
    videoDrivers = [ "intel" ];
    xkbOptions = "eurosign:e ctrl:nocaps";

    desktopManager = {
        default = "none";
        xterm.enable = false;
    };

    windowManager.i3 = {
        enable = true;
        extraPackages = with pkgs; [
            dmenu
            i3status
            i3lock
            i3blocks
        ];
    };
  };


  networking.interfaces.eno1.ipv4.addresses = [ {
    address = "192.168.1.10";
    prefixLength = 24;
  } ];
  networking.defaultGateway = "192.168.1.1";
  networking.nameservers = [ "8.8.8.8" "1.1.1.1"];

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 22 ];
  networking.firewall.allowPing = true;
 
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
   sound.enable = true;
   hardware.pulseaudio.enable = true;


  # Enable touchpad support.
  # services.xserver.libinput.enable = true;

  # Enable the KDE Desktop Environment.
  # services.xserver.displayManager.sddm.enable = true;
  # services.xserver.desktopManager.plasma5.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.miguel = {
     isNormalUser = true;
     extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
     shell = "/run/current-system/sw/bin/zsh";
  };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "19.03"; # Did you read the comment?

  nixpkgs.config.allowUnfree = true;
}