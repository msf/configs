# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "usb_storage" "uas" "sd_mod" ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/1b2dbd27-3b84-487e-b9bd-cce2c4a1cb04";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-id/ata-SanDisk_SDMSATA256G_164642400538-part1";
      fsType = "vfat";
    };

  fileSystems."/home" =
    { device = "/dev/disk/by-uuid/6febb429-5433-49cf-b14b-8536367fd298";
      fsType = "ext4";
    };

  fileSystems."/media/simple" =
    { device = "simple";
      fsType = "zfs";
    };

  fileSystems."/media/simple/backups" =
    { device = "simple/backups";
      fsType = "zfs";
    };

  fileSystems."/media/simple/backups-caitlin" =
    { device = "simple/backups-caitlin";
      fsType = "zfs";
    };

  fileSystems."/media/simple/restic" =
    { device = "simple/restic";
      fsType = "zfs";
    };

  fileSystems."/media/backups/syncthing" =
    { device = "backups/syncthing";
      fsType = "zfs";
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/cb2560ee-f36e-4dbf-ace3-b7a6ecb51bc8"; }
    ];

  nix.maxJobs = lib.mkDefault 4;
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";
}
