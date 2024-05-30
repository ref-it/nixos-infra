{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.nextcloud;
in
{
  options.profiles.nextcloud = {
    enable = mkEnableOption (mdDoc "Enable the Nextcloud profile");

    fqdn = mkOption {
      type = types.str;
      description = mdDoc ''
        The FQDN for the nginx vHost of the Nextcloud.
      '';
    };

    extraDomains = mkOption {
      type = types.listOf types.str;
      default = [];
      description = mdDoc ''
        Additional domains under which the Nextcloud shoud be reachable.
      '';
    };

    trustedProxies = mkOption {
      type = types.listOf types.str;
      default = [];
      description = mdDoc ''
        Trusted proxies for the Nextcloud.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
      settings.mysqld = {
        innodb_buffer_pool_size = "4096M";
      };
      ensureDatabases = [ config.services.nextcloud.config.dbname ];
      ensureUsers = [{
        name = config.services.nextcloud.config.dbuser;
        ensurePermissions = { "${config.services.nextcloud.config.dbname}.*" = "ALL PRIVILEGES"; };
      }];
    };

    sops.secrets = {
      "nc-init-pw" = {
        owner = "nextcloud";
        group = "nextcloud";
        mode = "0400";
      };
      "borg-passphrase" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    systemd.services.nextcloud-setup.after = [ "mysql.service" ];

    services.nextcloud = {
      enable = true;
      package = pkgs.nextcloud29;
      https = true;
      hostName = cfg.fqdn;
      autoUpdateApps.enable = true;
      configureRedis = true;
      maxUploadSize = "2048M";
      phpOptions = {
        "opcache.interned_strings_buffer" = "64";
        "opcache.memory_consumption" = "1024";
      };
      settings = {
        trusted_domains = cfg.extraDomains;
        maintenance_window_start = "2";
        trusted_proxies = cfg.trustedProxies;
        default_phone_region = "DE";
      };
      config = {
        dbtype = "mysql";
        dbname = "nextcloud";
        dbuser = "nextcloud";
        adminuser = "admin";
        adminpassFile = config.sops.secrets."nc-init-pw".path;
        dbhost = "localhost:/run/mysqld/mysqld.sock";
      };
    };

    services.borgbackup.jobs.nextcloud = {
      user = "root";
      group = "root";
      repo = "ssh://backup:23/./cloud";
      readWritePaths = [ "/var/lib/nextcloud/db-backup" ];
      preHook = ''
        cd /var/lib/nextcloud

        rm -f db-backup/*

        ${pkgs.mariadb}/bin/mysqldump ${config.services.nextcloud.config.dbname} > db-backup/${config.services.nextcloud.config.dbname}.sql
      '';
      paths = [ "config/config.php" "data" "db-backup" ];
      doInit = false;
      startAt = [ "*-*-* 04:00:00" ];
      encryption.mode = "repokey";
      encryption.passCommand = "cat ${config.sops.secrets."borg-passphrase".path}";
      prune.keep.within = "1y";
      compression = "auto,zstd";
      dateFormat = "+%Y-%m-%d";
      archiveBaseName = "backup";
    };
  };
}
