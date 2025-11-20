{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  config = {
    system.stateVersion = "23.05";

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking.hostName = "moralelastix";

    base.primaryIP = "2001:638:904:ffd0::7";

    systemd.network = {
      enable = true;
      networks = {
        "40-ens18" = {
          name = "ens18";
          networkConfig = {
            IPv6AcceptRA = false;
          };
          address = [
            "2001:638:904:ffd0::12/64"
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
            "10.170.20.109/24"
          ];
        };
      };
    };

    sops.defaultSopsFile = ./secrets.yaml;

    services.nginx = {
      virtualHosts = {
        "kiste.stura-ilmenau.de" = {
          forceSSL = true;
          enableACME = true;
          locations = {
            "/" = {
              proxyPass = "http://";
              recommendedProxySettings = true;
            };
          };
        };
      };
    };

    profiles.opencloud-kiste = {
      enable = true;
      fqdn = "kiste.stura-ilmenau.de";
    };
  };
}
