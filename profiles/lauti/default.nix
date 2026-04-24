{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.lauti;
in
{
  options.profiles.lauti = {
    enable = mkEnableOption (mdDoc "Enable the Lauti profile");

    fqdn = mkOption {
      type = types.str;
      description = mdDoc ''
        The FQDN of Lauti.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.extraInputRules = ''
      ip saddr 10.170.20.0/24 tcp dport { 80, 443 } accept
    '';

    sops.secrets = {
      "tls-cert" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "tls-cert-key" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "lauti-env" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts."${cfg.fqdn}" = {
        locations."/" = {
          proxyPass = "http://localhost:3333";
          recommendedProxySettings = true;
          extraConfig = ''
            allow 10.170.20.105;
            deny all;
          '';
        };
      };
    };

    services.lauti = {
      enable = true;
      settings = {
        LAUTI_BASE_URL = "https://${cfg.fqdn}";
        LAUTI_TIMEZONE = "Europe/Berlin";
        LAUTI_LOCALE = "de_DE";
        LAUTI_ADDR = ":3333";
        LAUTI_MAIL_SMTP_HOST = "imap.fem.tu-ilmenau.de:587";
        LAUTI_MAIL_SMTP_SECURE = "StartTLS";
        LAUTI_OSM_TILE_SERVER = "https://tile.openstreetmap.org/{z}/{x}/{y}.png";
        LAUTI_OSM_TILE_CACHE_DIR = "/var/lib/eintopf/osm";
      };
      secrets = [
        config.sops.secrets."lauti-env".path
      ];
    };
  };
}
