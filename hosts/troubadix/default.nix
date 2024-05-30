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

    base.primaryIP = "2001:638:904:ffd0::22";

    systemd.network = {
      enable = true;
      networks = {
        "40-ens18" = {
          name = "ens18";
          networkConfig = {
            IPv6AcceptRA = false;
          };
          address = [
            "2001:638:904:ffd0::22/64"
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
            "10.170.20.107/24"
          ];
        };
        "60-ens20" = {
          name = "ens20";
          networkConfig = {
            IPv6AcceptRA = false;
          };
          address = [
            "141.24.220.141/26"
          ];
          gateway = [
            "141.24.220.190"
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
