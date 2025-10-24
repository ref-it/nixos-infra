{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  config = {
    system.stateVersion = "23.05";

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking.hostName = "verliernix";

    base.primaryIP = "2001:638:904:ffd0::11";

    systemd.network = {
      enable = true;
      networks = {
        "40-ens18" = {
          name = "ens18";
          networkConfig = {
            IPv6AcceptRA = false;
          };
          address = [
            "2001:638:904:ffd0::11/64"
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
            "10.170.20.120/24"
          ];
          gateway = [
            "10.170.20.1"
          ];
        };
      };
    };
    
    sops.defaultSopsFile = ./secrets.yaml;

    profiles.vaultwarden = {
      enable = true;
      fqdn = "vault.stura-ilmenau.de";
    };
  };
}
