{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.reverse-proxy;
in
{
  options.profiles.reverse-proxy = {
    enable = mkEnableOption "reverse-proxy";

    httpProxy = mkOption {
      description = "HTTP proxy configs";
      type = types.listOf (types.submodule {
        options = {
          sources = mkOption {
            type = types.listOf types.str;
            description = ''
              Domains for this reverse proxy.
              The first domain in the list will be used as the server name.
            '';
          };
          target = mkOption {
            type = types.str;
            description = "Target of the reverse proxy.";
          };
        };
      });
    };

    streamProxy = mkOption {
      description = "Stream proxy configs";
      type = types.listOf (types.submodule {
        options = {
          proto = mkOption {
            type = types.enum [ "tcp" "udp" ];
            description = ''
              Protocol to proxy.
            '';
          };
          port = mkOption {
            type = types.port;
            description = "Port to listen on for the proxy.";
          };
          target = mkOption {
            type = types.str;
            description = "Target of the stream proxy.";
          };
        };
      });
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 80 443 ] ++
      (builtins.map (x: x.port) (builtins.filter (x: x.proto == "tcp") cfg.streamProxy));
    networking.firewall.allowedUDPPorts = builtins.map (x: x.port) (builtins.filter (x: x.proto == "udp") cfg.streamProxy);

    services.nginx = {
      enable = true; 
      recommendedProxySettings = true;
      streamConfig = concatStringsSep "\n" (builtins.map (x: let 
        listen = if x.proto == "tcp" then "${toString x.port}" else "${toString x.port} udp";
      in ''
        server {
          listen ${listen};
          listen [::]:${listen};
          proxy_pass ${x.target}; 
        }
      '') cfg.streamProxy);
      virtualHosts = listToAttrs (builtins.map (x: let
        serverName = builtins.head x.sources;
        aliases = drop 1 x.sources;
      in {
        name = serverName;
        value = {
          serverAliases = aliases;
          enableACME = true;
          forceSSL = true;
          locations."/" = {
            proxyPass = x.target;
            extraConfig = ''
              proxy_ssl_verify off;
            '';
          };
          extraConfig = ''
            client_max_body_size 512M;
          '';
        };
      }) cfg.httpProxy);
    };
  };
}
