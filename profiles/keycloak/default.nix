{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.keycloak;
in
{
  options.profiles.keycloak = {
    enable = mkEnableOption (mdDoc "Enable the Keycloak profile");

    fqdn = mkOption {
      type = types.str;
      description = mdDoc ''
        The FQDN of the Keycloak.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.extraInputRules = ''
      ip saddr 10.170.20.0/24 tcp dport { 80, 443 } accept
    '';

    sops.secrets = {
      "keycloak-db-pw" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "borg-passphrase" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
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
    };

    services.keycloak = {
      enable = true;
      database = {
        passwordFile = config.sops.secrets."keycloak-db-pw".path;
      };
      sslCertificate = config.sops.secrets."tls-cert".path;
      sslCertificateKey = config.sops.secrets."tls-cert-key".path;
      settings = {
        hostname = cfg.fqdn;
        reverse-proxy-headers = "xforwarded";
        log-console-level = "debug";
        log-syslog-level = "debug";
      };
    };

    services.postgresqlBackup = {
      enable = true;
      startAt = "*-*-* 03:00:00";
      databases = [ "keycloak" ];
    };

    services.borgbackup.jobs.keycloak = {
      user = "root";
      group = "root";
      repo = "ssh://backup:23/./keycloak";
      paths = [ "/var/backup/postgresql/keycloak.sql.gz" ];
      doInit = false;
      startAt = [ "*-*-* 03:30:00" ];
      encryption.mode = "repokey";
      encryption.passCommand = "cat ${config.sops.secrets."borg-passphrase".path}";
      prune.keep.within = "1y";
      compression = "auto,zstd";
      dateFormat = "+%Y-%m-%d";
      archiveBaseName = "backup";
    };
  };
}
