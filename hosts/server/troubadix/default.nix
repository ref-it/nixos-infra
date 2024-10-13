{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  config = {
    system.stateVersion = "24.05";

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking.hostName = "troubadix";

    base.primaryIP = "2001:638:904:ffd0::25";

    systemd.network = {
      enable = true;
      networks = {
        "40-ens18" = {
          name = "ens18";
          networkConfig = {
            IPv6AcceptRA = false;
          };
          address = [
            "2001:638:904:ffd0::25/64"
          ];
          gateway = [
            "2001:638:904:ffd0::1"
          ];
        };
      };
    };

    sops.defaultSopsFile = ./secrets.yaml;

    profiles.matrix = {
      enable = true;
      fqdn = "stura.eu";
    };
  };
}
