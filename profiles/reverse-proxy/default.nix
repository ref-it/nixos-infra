{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.reverse-proxy;
in
{
  options.profiles.reverse-proxy = {
    enable = mkEnableOption "reverse-proxy";

    allowedIPs = mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        List of IP addresses that can access restricted locations.
      '';
    };

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
          extraConfig = mkOption {
            type = types.lines;
            default = "";
            description = ''
              Extra config for the nginx location of the proxy.
            '';
          };
          unrestrictedLocations = mkOption {
            type = types.nullOr (types.listOf types.str);
            default = null;
            description = ''
              Explicit forwarded unrestricted locations.
              If set, only the given locations will be proxied.
            '';
          };
          restrictedLocations = mkOption {
            type = types.listOf types.str;
            default = [];
            description = ''
              Locations with IP limitations to StuRa IPs.
            '';
          };
          websocket = {
            enable = mkOption {
              type = types.bool;
              default = false;
              description = ''
                Enable websocket proxying.
              '';
            };
            target = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                Proxy target for the websocket.
              '';
            };
            locations = mkOption {
              type = types.listOf types.str;
              description = ''
                Locations to forward to the websocket.
              '';
            };
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
        unrestrictedLocations = if (x.unrestrictedLocations != null) then (listToAttrs (builtins.map (y: {
          name = y;
          value = {
            proxyPass = x.target;
            extraConfig = ''
              proxy_ssl_verify off;
            '' + x.extraConfig;
          };
        }) x.unrestrictedLocations)) else null;
        restrictedLocations = listToAttrs (builtins.map (y: {
          name = y;
          value = {
            proxyPass = x.target;
            extraConfig = ''
              proxy_ssl_verify off;
              ${concatStringsSep "\n" (builtins.map (z: "allow " + z + ";") cfg.allowedIPs)}
              deny all;
            '' + x.extraConfig;
          };
        }) x.restrictedLocations);
        websocketLocations = listToAttrs (builtins.map (y: {
          name = y;
          value = {
            proxyPass = if x.websocket.target != null then x.websocket.target else x.target;
            extraConfig = ''
              proxy_ssl_verify off;
              proxy_http_version 1.1;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "Upgrade";
            '' + x.extraConfig;
          };
        }) x.websocket.locations);
      in {
        name = serverName;
        value = {
          serverAliases = aliases;
          enableACME = true;
          forceSSL = true;
          locations = if (x.unrestrictedLocations == null) then {
            "/" = {
              proxyPass = x.target;
              extraConfig = ''
                proxy_ssl_verify off;
              '' + x.extraConfig;
            };
          } else unrestrictedLocations
          // restrictedLocations
          // (if x.websocket.enable then websocketLocations else {});
          extraConfig = ''
            client_max_body_size 512M;
          '';
        };
      }) cfg.httpProxy);
    };
  };
}
