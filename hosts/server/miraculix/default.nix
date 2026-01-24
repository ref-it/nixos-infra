{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  config = {
    system.stateVersion = "23.05";

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking.hostName = "miraculix";

    base.primaryIP = "2001:638:904:ffd0::15";

    systemd.network = {
      enable = true;
      networks = {
        "40-ens18" = {
          name = "ens18";
          networkConfig = {
            IPv6AcceptRA = false;
          };
          address = [
            "2001:638:904:ffd0::15/64"
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
            "10.170.20.104/24"
          ];
          gateway = [
            "10.170.20.1"
          ];
        };
      };
    };

    networking.extraHosts = ''
      2001:638:904:ffd0::24 ldap.stura-ilmenau.de
    '';

    sops.defaultSopsFile = ./secrets.yaml;

    profiles.zammad = {
      enable = true;
      bindHost = "0.0.0.0";
    };

    services.nginx = {
      virtualHosts = {
        "help.stura-ilmenau.de" = {
          locations = {
            "/" = {
              proxyPass = "http://0.0.0.0:3000";
              recommendedProxySettings = true;
              extraConfig = ''
                proxy_set_header CLIENT_IP $remote_addr;
              '';
            };
            "/ws" = {
              proxyPass = "http://0.0.0.0:6042";
              recommendedProxySettings = true;
              proxyWebsockets = true;
            };
            "/cable" = {
              proxyPass = "http://0.0.0.0:6042";
              recommendedProxySettings = true;
              proxyWebsockets = true;
            };
          };
        };
      };
    };
    
    environment.systemPackages = [
      pkgs.git
    ];
  };
}