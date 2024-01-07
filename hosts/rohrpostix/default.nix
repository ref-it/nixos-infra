{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  config = {
    system.stateVersion = "23.11";

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking.hostName = "rohrpostix";

    base.primaryIP = "2001:638:904:ffd0::6";

    systemd.network = {
      enable = true;
      networks = {
        "40-ens18" = {
          name = "ens18";
          networkConfig = {
            IPv6AcceptRA = false;
          };
          address = [
            "2001:638:904:ffd0::6/64"
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
            "10.170.20.105/24"
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

    profiles.reverse-proxy = {
      enable = true;
      httpProxy = [
        {
          sources = [
            "stura.tu-ilmenau.de"
            "www.stura.tu-ilmenau.de"
            "erstiwoche.de"
            "www.erstiwoche.de"
            "fachschaftsrat-ei.de"
            "www.fachschaftsrat-ei.de"
            "fachschaftsrat-mn.de"
            "www.fachschaftsrat-mn.de"
            "fachschaftsrat-mb.de"
            "www.fachschaftsrat-mb.de"
            "fachschaftsrat-wm.de"
            "www.fachschaftsrat-wm.de"
          ];
          target = "https://10.170.20.101";
        }
        {
          sources = [
            "auth.stura-ilmenau.de"
          ];
          target = "http://10.170.20.105";
        }
        {
          sources = [
            "cloud.stura-ilmenau.de"
            "cloud.stura.eu"
          ];
          target = "http://10.170.20.103";
        }
        {
          sources = [
            "help.stura-ilmenau.de"
          ];
          target = "http://10.170.20.104:3000";
          extraConfig = ''
            proxy_set_header CLIENT_IP $remote_addr;
          '';
          websocket = {
            enable = true;
            target = "http://10.170.20.104:6042";
            locations = [ "/ws" "/cable" ];
          };
        }
        {
          sources = [
            "projects.stura-ilmenau.de"
          ];
          target = "http://[2001:638:904:ffd0::14]";
        }
      ];
      streamProxy = [
        {
          proto = "tcp";
          port = 1022;
          target = "10.170.20.101:22";
        }
      ];
    };
  };
}
