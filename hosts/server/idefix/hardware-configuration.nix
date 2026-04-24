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
    { device = "/dev/disk/by-uuid/409ff832-ba23-4761-b712-d5ffacd2899b";
      fsType = "btrfs";
    };

  fileSystems."/var/lib/nextcloud" =
    { device = "/dev/disk/by-uuid/639a3aac-dd93-4419-9112-cfd29847cdff";
      fsType = "btrfs";
    };

  fileSystems."/var/lib/postgresql" =
    { device = "/dev/disk/by-uuid/427f2951-e20f-49c4-b921-b149c90006b6";
      fsType = "btrfs";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/4409-BD9C";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  fileSystems."/var/lib/lauti" =
    { device = "/dev/disk/by-uuid/cfd8d5d2-e885-44eb-9a49-887a216b3a94";
      fsType = "btrfs";
    };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}