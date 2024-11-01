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
      "tls-cert" = {
        owner = "nginx";
        group = "nginx";
        mode = "0400";
      };
      "tls-cert-key" = {
        owner = "nginx";
        group = "nginx";
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
          PAPERLESS_CORS_ALLOWED_HOSTS = "paperless.stura-ilmenau.de";
          PAPERLESS_ADMIN_MAIL = "ref-it@tu-ilmenau.de";
          PAPERLESS_TASK_WORKERS = 2;
          PAPERLESS_THREADS_PER_WORKER = 1;
          PAPERLESS_TIME_ZONE = "Europe/Berlin";
        };
        passwordFile = config.sops.secrets."paperless-pw".path;
      };

      nginx = {
        enable = true;
        virtualHosts."${cfg.fqdn}" = {
          forceSSL = true;
          sslCertificate = config.sops.secrets."tls-cert".path;
          sslCertificateKey = config.sops.secrets."tls-cert-key".path;
          locations."/" = {
            proxyPass = "http://127.0.0.1:28981";
          };
        };
      };
    };
  };
}
