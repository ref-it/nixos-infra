{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.collabora;
in
{
  options.profiles.collabora = {
    enable = mkEnableOption (mdDoc "Enable the Collabora profile");

    fqdn = mkOption {
      type = types.str;
      description = mdDoc ''
        The FQDN for the nginx vHost of Collabora.
      '';
    };

    trustedHosts = mkOption {
      type = types.listOf types.str;
      default = [];
      description = mdDoc ''
        List of hosts allowed to access Collabora Online.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    services.collabora-online = {
      enable = true;
      port = 9980;
      settings = {
        ssl = {
          enable = false;
          termination = true;
        };
        net = {
          listen = "loopback";
          post_allow.host = [
            "::1"
          ];
        };
        storage.wopi = {
          "@allow" = true;
          host = cfg.trustedHosts;
        };
        server_name = cfg.fqdn;
      };
    };

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts."${cfg.fqdn}" = {
        forceSSL = true;
        enableACME = true;
        locations = {
          "^~ /browser" = {
            priority = 10;
            proxyPass = "http://[::1]:${toString config.services.collabora-online.port}";
            extraConfig = ''
              proxy_set_header Host $host;
            '';
          };
          "^~ /hosting/discovery" = {
            priority = 20;
            proxyPass = "http://[::1]:${toString config.services.collabora-online.port}";
            extraConfig = ''
              proxy_set_header Host $host;
            '';
          };
          "^~ /hosting/capabilities" = {
            priority = 30;
            proxyPass = "http://[::1]:${toString config.services.collabora-online.port}";
            extraConfig = ''
              proxy_set_header Host $host;
            '';
          };
          "~ ^/cool/(.*)/ws$" = {
            priority = 40;
            proxyPass = "http://[::1]:${toString config.services.collabora-online.port}";
            extraConfig = ''
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "Upgrade";
              proxy_set_header Host $host;
              proxy_read_timeout 36000s;
            '';
          };
          "~ ^/(c|l)ool" = {
            priority = 50;
            proxyPass = "http://[::1]:${toString config.services.collabora-online.port}";
            extraConfig = ''
              proxy_set_header Host $host;
            '';
          };
          "^~ /cool/adminws" = {
            priority = 60;
            proxyPass = "http://[::1]:${toString config.services.collabora-online.port}";
            extraConfig = ''
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "Upgrade";
              proxy_set_header Host $host;
              proxy_read_timeout 36000s;
            '';
          };
        };
      };
    };
  };
}
