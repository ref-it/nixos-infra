{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.pretix;
in
{
  options.profiles.pretix = {
    enable = mkEnableOption (mdDoc "Enable the Pretix profile");

    fqdn = mkOption {
      type = types.str;
      description = mdDoc ''
        The FQDN for the nginx vHost of Pretix.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    sops.secrets = {
      "borg-passphrase" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    services.pretix = {
      enable = true;
      gunicorn.extraArgs = [
        "--name=pretix"
        "--workers=8"
      ];
      nginx.domain = cfg.fqdn;
      settings = {
        pretix = {
          instance_name = cfg.fqdn;
          registration = false;
          url = "https://${cfg.fqdn}";
          currency = "EUR";
        };
        languages = {
          enabled = "de,en";
        };
        locale = {
          default = "de";
          timezone = "Europe/Berlin";
        };
        mail = {
          from = "pretix@stura-ilmenau.de";
          host = "imap.fem.tu-ilmenau.de";
          port = 587;
          tls = "on";
        };
      };
      environmentFile = "/var/lib/pretix.env";
      plugins = with config.services.pretix.package.plugins; [
        zugferd
      ];
    };

    services.postgresqlBackup = {
      enable = true;
      startAt = "*-*-* 03:20:00";
      databases = [ "pretix" ];
    };

    services.borgbackup.jobs.pretix = {
      user = "root";
      group = "root";
      repo = "ssh://backup:23/./pretix";
      paths = [ "/var/lib/pretix" "/var/backup/postgresql/pretix.sql.gz" ];
      doInit = false;
      startAt = [ "*-*-* 03:50:00" ];
      encryption.mode = "repokey";
      encryption.passCommand = "cat ${config.sops.secrets."borg-passphrase".path}";
      prune.keep.within = "1y";
      compression = "auto,zstd";
      dateFormat = "+%Y-%m-%d";
      archiveBaseName = "backup";
    };
  };
}
