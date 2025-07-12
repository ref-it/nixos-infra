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
      virtualHosts."{$cfg.fqdn} =  {
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://[::1]:${toString config.services.collabora-online.port}";
          proxyWebsockets = true; # collabora uses websockets
        };
      };
    };
  };
}
