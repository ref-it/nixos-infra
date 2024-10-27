{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.paperless;
in
{
  options.profiles.paperless = {
    enable = mkEnableOption (mdDoc "Enable the paperless-ngx profile");

    fqdn = mkOption {
      type = types.str;
      description = mdDoc ''
        The FQDN for the nginx vHost of paperless-ngx.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    sops.secrets = {
      "paperless-pw" = {
        owner = "paperless";
        group = "paperless";
        mode = "0400";
      };
    };

    systemd.services.paperless-scheduler.after = [ "postgresql.service" ];

    services = {
      postgresql = {
        enable = true;
        ensureDatabases = [ "paperless" ];
        ensureUsers = [
          {
            name = "paperless";
            ensureDBOwnership = true;
          }
        ];
      };

      paperless = {
        enable = true;
        settings = {
          PAPERLESS_DBHOST = "/run/postgresql";
          PAPERLESS_OCR_LANGUAGE = "deu+eng";
        };
        passwordFile = config.sops.secrets."paperless-pw".path;
      };

      nginx = {
        enable = true;
        virtualHosts."${cfg.fqdn}" = {
          locations."/" = {
            proxyPass = "http://localhost:28981/";
          };
        };
      };
    };
  };
}
