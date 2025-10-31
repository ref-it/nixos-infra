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

    services.nginx = {
      virtualHosts."matrix-admin.stura.eu" = {
        enableACME = true;
        forceSSL = true;
        locations."/".root = pkgs.synapse-admin;
      };
    };

    profiles.reverse-proxy = {
      enable = true;
      allowedIPs = [
        "141.24.44.128/25"
        "2001:638:904:ffd0::/64"
      ];
      httpProxy = [
        {
          sources = [
            "ep.stura-ilmenau.de"
            "ep.erstiwiki.de"
          ];
          target = "https://10.170.20.114";
        }
        {
          sources = [
            "hedgedoc.stura-ilmenau.de"
          ];
          target = "https://10.170.20.114";
        }
        {
          sources = [
            "helfer.stura-ilmenau.de"
            "helfer.erstiwoche.de"
            "helfer.fsr-ia.de"
          ];
          target = "https://10.170.20.111";
          extraConfig = ''
            proxy_set_header X-Forwarded-For $remote_addr;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
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
            "infoscreen.stura-ilmenau.de"
          ];
          target = "http://10.170.20.113";
        }
        {
          sources = [
            "matrix.stura.eu"
          ];
          unrestrictedLocations = [ "~ ^(/_matrix|/_synapse/client|/_synapse/admin)" ];
          target = "http://10.170.20.107:8008";
        }
        {
          sources = [
            "projects.stura-ilmenau.de"
          ];
          target = "http://10.170.20.110";
        }
        {
          sources = [
            "tickets.stura-ilmenau.de"
            "tickets.erstiwoche.de"
            "tickets.fsr-ei.de"
            "tickets.fsr-ia.de"
            "tickets.fsr-mb.de"
            "tickets.fsr-mn.de"
            "tickets.fsr-wm.de"
            "tickets.studierendenbeirat.de"
          ];
          target = "http://10.170.20.112";
        }
        {
          sources = [
            "vault.stura-ilmenau.de"
          ];
          target = "https://10.170.20.120";
          websocket = {
            enable = true;
            target = "https://10.170.20.120";
            locations = [ "/" ];
          };
        }
      ];
      redirectPermanent = [
        {
          sources = [
            "stura.tu-ilmenau.de"
            "www.stura.tu-ilmenau.de"
          ];
          target = "www.stura-ilmenau.de";
        }
        {
          sources = [
            "cloud.stura.eu"
            "cloud.stura.tu-ilmenau.de"
          ];
          target = "cloud.stura-ilmenau.de";
        }
        {
          sources = [
            "fachschaftsrat-ei.de"
            "www.fachschaftsrat-ei.de"
          ];
          target = "fsr-ei.de";
        }
        {
          sources = [
            "fachschaftsrat-mb.de"
            "www.fachschaftsrat-mb.de"
          ];
          target = "fsr-mb.de";
        }
        {
          sources = [
            "fachschaftsrat-mn.de"
            "www.fachschaftsrat-mn.de"
          ];
          target = "fsr-mn.de";
        }
        {
          sources = [
            "fachschaftsrat-wm.de"
            "www.fachschaftsrat-wm.de"
          ];
          target = "fsr-wm.de";
        }
        {
          sources = [
            "finanzen.stura.eu"
          ];
          target = "finanzen.stura-ilmenau.de";
        }
        {
          sources = [
            "helfer.stura.tu-ilmenau.de"
            "helper.stura.tu-ilmenau.de"
          ];
          target = "helfer.stura-ilmenau.de";
        }
        {
          sources = [
            "protokoll.stura.tu-ilmenau.de"
          ];
          target = "protokoll.stura-ilmenau.de";
        }
        {
          sources = [
            "stubra.de"
            "www.stubra.de"
            "studentenbeirat.de"
            "www.studentenbeirat.de"
          ];
          target = "studierendenbeirat.de";
        }
        {
          sources = [
            "wahlen.stura.tu-ilmenau.de"
          ];
          target = "wahlen.stura-ilmenau.de";
        }
        {
          sources = [
            "wiki.stura.tu-ilmenau.de"
          ];
          target = "wiki.stura-ilmenau.de";
        }
        {
          sources = [
            "fh-ilmenau.de"
            "www.fh-ilmenau.de"
            "th-ilmenau.de"
            "www.th-ilmenau.de"
            "studis-gegen-rechtsextremismus.de"
            "www.studis-gegen-rechtsextremismus.de"
          ];
          target = "www.stura-ilmenau.de";
        }
        {
          sources = [
            "markus-soeder-uni.de"
            "www.markus-soeder-uni.de"
            "xn--markus-sder-uni-gtb.de"
            "www.xn--markus-sder-uni-gtb.de"
          ];
          target = "medtech.fsi.fau.de";
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
