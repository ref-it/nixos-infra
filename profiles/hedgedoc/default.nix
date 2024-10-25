{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.hedgedoc;
in
{
  options.profiles.hedgedoc = {
    enable = mkEnableOption (mdDoc "Enable the Hedgedoc profile");

    fqdn = mkOption {
      type = types.str;
      description = mdDoc ''
        The FQDN for the nginx vHost of Hedgedoc.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    services = {
      hedgedoc = {
        enable = true;
        package = pkgs.hedgedoc;
        settings = {
          domain = cfg.fqdn;
          protocolUseSSL = true;
          db = {
            username = "hedgedoc";
            database = "hedgedoc";
            host = "/run/postgresql";
            dialect = "postgresql";
          };
        };
      };
      nginx = {
        enable = true;
        virtualHosts = {
          "hedgedoc.stura-ilmenau.de" = {
            locations."/" = {
              proxyPass = "http://[::1]:3000";
              extraConfig = ''
                proxy_set_header Host $host; 
                proxy_set_header X-Real-IP $remote_addr; 
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; 
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_headers_hash_bucket_size 128;
              '';
            };
            locations."/socket.io/" = {
              proxyPass = "http://[::1]:3000/socket.io/";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_set_header Host $host; 
                proxy_set_header X-Real-IP $remote_addr; 
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; 
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_ssl_verify off;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection "Upgrade";
                proxy_headers_hash_bucket_size 128;
              '';
            };
          };
        };
      };
      postgresql = {
        enable = true;
        ensureDatabases = [ "hedgedoc" ];
        ensureUsers = [
          {
            name = "hedgedoc";
            ensureDBOwnership = true;
          }
        ];
      };
    };
  };
}