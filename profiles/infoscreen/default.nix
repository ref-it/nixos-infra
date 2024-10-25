{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.infoscreen;
in
{
  options.profiles.infoscreen = {
    enable = mkEnableOption (mdDoc "Enable the InfoScreen profile");

    fqdn = mkOption {
      type = types.str;
      description = mdDoc ''
        The FQDN for the nginx vHost of InfoScreen.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    services = {
      infoscreen = {
        enable = true;
      };
      nginx = {
        enable = true;
        virtualHosts = {
          "infoscreen.stura-ilmenau.de" = {
            locations."/" = {
              proxyPass = "http://localhost:3333";
              extraConfig = ''
                proxy_set_header Host $host; 
                proxy_set_header X-Real-IP $remote_addr; 
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; 
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_headers_hash_bucket_size 128;
              '';
            };
          };
        };
      };
    };
  };
}