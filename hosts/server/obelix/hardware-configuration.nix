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
    { device = "/dev/disk/by-uuid/eefc2a59-96e1-473e-890d-4b51dd5a8681";
      fsType = "btrfs";
    };

  fileSystems."/var/lib/postgresql" =
    { device = "/dev/disk/by-uuid/98418e49-0207-4a50-8881-3da69bbb18c3";
      fsType = "btrfs";
    };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
