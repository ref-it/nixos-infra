{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  config = {
    system.stateVersion = "23.05";

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking.hostName = "barometrix";

    base.primaryIP = "2001:638:904:ffd0::20";

    systemd = {
      network = {
        enable = true;
        networks = {
          "40-ens18" = {
            name = "ens18";
            networkConfig = {
              IPv6AcceptRA = false;
            };
            address = [
              "2001:638:904:ffd0::20/64"
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
              "10.170.20.113/24"
            ];
            gateway = [
              "10.170.20.1"
            ];
          };
        };
      };
      services.infoscreen = {
        description = "StuRa-InfoScreen";
        serviceConfig = {
          Type = "simple";
          WorkingDirectory = "/var/lib/infoscreen/server/";
          ExecStart = "/var/lib/infoscreen/server/./server";
          Restart = "always";
        };
        wantedBy = [ "default.target" ];
      };
      services.infoscreen.enable = true;
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];

    services.nginx = {
      enable = true;
      virtualHosts."infoscreen.stura-ilmenau.de" = {
        locations."/" = {
          proxyPass = "http://localhost:3000";
        };
      };
    };

    environment.systemPackages = [
      pkgs.git
      pkgs.go
      pkgs.nodejs_22
    ];

    /*profiles.infoscreen = {
      enable = true;
      fqdn = "infoscreen.stura-ilmenau.de";
    };*/
  };
}
