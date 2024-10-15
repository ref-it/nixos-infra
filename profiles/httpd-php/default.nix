{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.httpd-php;
in
{
  options.profiles.httpd-php = {
    enable = mkEnableOption (mdDoc "Enable the Apache httpd and PHP profile");

    fqdn = mkOption {
      type = types.str;
      description = mdDoc ''
        The FQDN of the app.
      '';
    };

    restricted = mkOption {
      type = types.bool;
      description = mdDoc ''
        Restriction to IP addresses of TU Ilmenau if true.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = if cfg.restricted then [] else [ 80 443 ];
    networking.firewall.extraInputRules = if cfg.restricted then ''
      ip6 saddr 2001:638:904::/48 tcp dport { 80, 443 } accept
    '' else "";

    services.httpd = {
      enable = true;
      adminAddr = "ref-it@tu-ilmenau.de";
      enablePHP = true;
      virtualHosts.${cfg.fqdn} = {
        documentRoot = "/var/www/${cfg.fqdn}/public_html";
        forceSSL = true;
        enableACME = true;
      };
    };
  };
}
