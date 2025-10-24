{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.vaultwarden;
in
{
  options.profiles.vaultwarden = {
    enable = mkEnableOption (mdDoc "Enable the Vaultwarden profile");

    fqdn = mkOption {
      type = types.str;
      description = mdDoc ''
        The FQDN for the nginx vHost of Vaultwarden.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    sops.secrets = {
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

    services.postgresql = {
      enable = true;
      ensureDatabases = [ "vaultwarden" ];
      ensureUsers = [
        {
          name = "vaultwarden";
          ensureDBOwnership = true;
        }
      ];
    };

    services.vaultwarden = {
      enable = true;
      package = pkgs.vaultwarden-postgresql;
      dbBackend = "postgresql";
      config = {
        DOMAIN = "https://${cfg.fqdn}";
        SIGNUPS_ALLOWED = false;
        EMERGENCY_ACCESS_ALLOWED = false;
        EMAIL_CHANGE_ALLOWED = false;
        PASSWORD_HINTS_ALLOWED = false;
        SMTP_HOST = "imap.fem.tu-ilmenau.de";
        SMTP_PORT = 587;
        SMTP_SECURITY = "starttls";
        SMTP_FROM = "vaultwarden@stura-ilmenau.de";
        SMTP_FROM_NAME = "Vaultwarden | Studierendenrat Ilmenau";
        DATABASE_URL = "postgresql:///vaultwarden?host=/run/postgresql";
        ROCKET_ADDRESS = "::1";
        ROCKET_PORT = 8222;
      };
      environmentFile = "/var/lib/vaultwarden.env";
    };

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts."${cfg.fqdn}" = {
        forceSSL = true;
        sslCertificate = config.sops.secrets."tls-cert".path;
        sslCertificateKey = config.sops.secrets."tls-cert-key".path;
        locations."/" = {
          proxyPass = "http://localhost:8222";
          extraConfig = ''
            proxy_set_header Host $host; 
            proxy_set_header X-Real-IP $remote_addr; 
            allow 10.170.20.105;
            deny all;
          '';
          proxyWebsockets = true;
        };
      };
    };
  };
}
