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
    { device = "/dev/disk/by-uuid/503ef981-5403-4cf3-b9e9-e1293eb97cf9";
      fsType = "btrfs";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/28CA-1AF0";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  fileSystems."/var/lib/postgresql" =
    { device = "/dev/disk/by-uuid/9b045ea5-17c7-4034-a19a-a9d9b82f20d2";
      fsType = "btrfs";
    };

  fileSystems."/var/lib/nextcloud" =
    { device = "/dev/disk/by-uuid/14e15c9b-d13e-4088-92e3-2f938497a2aa";
      fsType = "btrfs";
    };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
