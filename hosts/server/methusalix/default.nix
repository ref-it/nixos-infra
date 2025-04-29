{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  config = {
    system.stateVersion = "23.05";

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking.hostName = "methusalix";

    base.primaryIP = "2001:638:904:ffd0::1e";

    systemd.network = {
      enable = true;
      networks = {
        "40-ens18" = {
          name = "ens18";
          networkConfig = {
            IPv6AcceptRA = false;
          };
          address = [
            "2001:638:904:ffd0::1e/64"
          ];
          gateway = [
            "2001:638:904:ffd0::1"
          ];
        };
        "50-ens19" = {
          name = "ens19";
          networkConfig = {
            IPv6AcceptRA = false;
          };
          address = [
            "10.170.20.119/24"
          ];
          gateway = [
            "10.170.20.1"
          ];
        };
      };
    };

    sops.defaultSopsFile = ./secrets.yaml;

    profiles.pretalx = {
      enable = true;
      fqdn = "talks.stura-ilmenau.de";
    };
  };
}
