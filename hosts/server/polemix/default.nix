{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  config = {
    system.stateVersion = "23.05";

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking.hostName = "polemix";

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
        };
      };
      user.services.etherpad = {
        description = "Etherpad Lite";
        after = ["syslog.target" "network.target"];
        serviceConfig = {
          Type = "simple";
          WorkingDirectory = "/var/etherpad";
          ExecStart = "pnpm run prod";
          Environment = "NODE_ENV=production";
          Restart = "always";
        };
        wantedBy = [ "multi-user.target" ];
      };
      services.etherpad.enable = true;
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];

    services.nginx = {
      enable = true;
      virtualHosts."pad.stura-ilmenau.de" = {
        locations."/" = {
          proxyPass = "http://localhost:9001";
        };
      };
    };

    environment.systemPackages = [
      pkgs.git
      pkgs.nodejs_20
    ];
  };
}
