{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/profiles/qemu-guest.nix")
    ];

  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/10d9fd17-39cd-4277-87bb-1b5b4fddd9e3";
      fsType = "btrfs";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/C70D-E4BF";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  fileSystems."/var/lib/nextcloud" =
    { device = "/dev/disk/by-uuid/cc77aeff-295a-482a-b9ad-9b37a016ec3c";
      fsType = "btrfs";
    };

  fileSystems."/var/lib/mysql" =
    { device = "/dev/disk/by-uuid/014eb342-7855-4990-8d58-dcbb947b70a7";
      fsType = "btrfs";
    };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}