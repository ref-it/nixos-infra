{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  config = {
    system.stateVersion = "23.05";

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking.hostName = "obelix";

    base.primaryIP = "2001:638:904:ffd0::12";

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
            "10.170.20.103/24"
          ];
        };
        "60-ens20" = {
          name = "ens20";
          networkConfig = {
            IPv6AcceptRA = false;
          };
          address = [
            "141.24.220.139/26"
          ];
          gateway = [
            "141.24.220.190"
          ];
        };
      };
    };

    sops.defaultSopsFile = ./secrets.yaml;

    services.nginx = {
      virtualHosts = {
        "box.stura.tu-ilmenau.de" = {
          forceSSL = true;
          enableACME = true;
          globalRedirect = "cloud.stura-ilmenau.de";
        };
        "cloud.stura-ilmenau.de" = {
          forceSSL = true;
          enableACME = true;
        };

        "auth.stura-ilmenau.de" = {
          forceSSL = true;
          enableACME = true;
          extraConfig = ''
            set_real_ip_from 0.0.0.0/0;
            real_ip_header X-Real-IP;
            real_ip_recursive on;
          '';
          locations = {
            "/" = {
              proxyPass = "https://10.170.20.106";
              extraConfig = ''
                proxy_redirect off;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $remote_addr;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_set_header X-Forwarded-Port 443;
              '';
            };
            "/admin" = {
              proxyPass = "https://10.170.20.106";
              extraConfig = ''
                allow 141.24.0.0/16;
                allow 2001:638:904::/48;
                deny all;
              '';
            };
          };
        };
      };
    };

    profiles.nextcloud = {
      enable = true;
      fqdn = "cloud.stura-ilmenau.de";
      trustedProxies = [
        "2001:638:904:ffd0::12"
      ];
    };

    profiles.nextcloud-kiste = {
      enable = true;
      name = "nextcloud-kiste";
      fqdn = "kiste.stura-ilmenau.de";
      dir = "/var/lib/nextcloud-kiste";
    };

    profiles.collabora = {
      enable = true;
      fqdn = "office.stura-ilmenau.de";
      trustedHosts = [
        "cloud.stura-ilmenau.de"
        "2001:638:904:ffd0::12"
      ];
    };
  };
}
