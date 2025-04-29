{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.pretalx;
in
{
  options.profiles.pretalx = {
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

    services.pretalx = {
      enable = true;
      gunicorn.extraArgs = [
        "--name=pretalx"
        "--workers=8"
      ];
      nginx.domain = cfg.fqdn;
      settings = {
        mail = {
          from = "pretalx@stura-ilmenau.de";
          host = "imap.fem.tu-ilmenau.de";
          port = 587;
          user = "pretalx@stura-ilmenau.de";
        };
      };
    };

    /*services.borgbackup.jobs.pretalx = {
      user = "root";
      group = "root";
      repo = "ssh://backup:23/./pretalx";
      readWritePaths = [ "/var/lib/pretalx/db-backup" ];
      preHook = ''
        cd /var/lib/pretalx

        rm -f db-backup/*

        ${pkgs.mariadb}/bin/mysqldump ${config.services.pretalx.settings.database.name} > db-backup/${config.services.pretalx.settings.database.name}.sql
      '';
      paths = [ "config/config.php" "data" "db-backup" ];
      doInit = false;
      startAt = [ "*-*-* 03:30:00" ];
      encryption.mode = "repokey";
      encryption.passCommand = "cat ${config.sops.secrets."borg-passphrase".path}";
      prune.keep.within = "1y";
      compression = "auto,zstd";
      dateFormat = "+%Y-%m-%d";
      archiveBaseName = "backup";
    };*/
  };
}
