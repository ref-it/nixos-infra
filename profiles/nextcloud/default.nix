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

    memoryGB = mkOption {
      type = types.ints.positive;
      default = 8;
      description = mdDoc ''
        Amount of RAM in GiB available to the host. Used to size the
        PostgreSQL memory settings; set this to the actual memory of the
        machine, otherwise PostgreSQL stays at its defaults.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 80 443 ];

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

    services.nginx.virtualHosts."${cfg.fqdn}" = {
      forceSSL = true;
      enableACME = true;
    };

    services.nextcloud = {
      enable = true;
      package = pkgs.nextcloud35;
      phpPackage = pkgs.php85;
      https = true;
      hostName = cfg.fqdn;
      autoUpdateApps.enable = true;
      configureRedis = true;
      maxUploadSize = "2048M";
      phpOptions = {
        "opcache.interned_strings_buffer" = "64";
        "opcache.memory_consumption" = "1024";
      };
      database.createLocally = true;
      settings = {
        trusted_domains = cfg.extraDomains;
        maintenance_window_start = "2";
        trusted_proxies = cfg.trustedProxies;
        default_phone_region = "DE";
        user_oidc = {
          auto_provision = false;
        };
        mail_sendmailmode = "smtp";
        mail_smtpmode = "smtp";
        mail_smtphost = "imap.fem.tu-ilmenau.de";
        mail_smtpport = 587;
        mail_from_address = "cloud";
        mail_domain = "stura-ilmenau.de";
        mail_smtpauth = true;
        mail_smtpname = "cloud@stura-ilmenau.de";
        "simpleSignUpLink.shown" = false;
        serverid = 1;
      };
      config = {
        adminuser = "admin";
        adminpassFile = config.sops.secrets."nc-init-pw".path;
        dbtype = "pgsql";
      };
      caching = {
        redis = true;
        memcached = true;
      };
      extraAppsEnable = true;
      extraApps = with config.services.nextcloud.package.packages.apps; {
        inherit calendar contacts deck forms groupfolders notify_push polls richdocuments spreed tables tasks user_oidc;
      };
    };

    services.postgresql.settings = {
      shared_buffers = "256MB";
      effective_cache_size = "${toString (cfg.memoryGB * 768)}MB";
      maintenance_work_mem = "${toString (min 2048 (cfg.memoryGB * 64))}MB";
      work_mem = "16MB";
      random_page_cost = "1.1";
      effective_io_concurrency = 200;
    };

    services.postgresqlBackup = {
      enable = true;
      startAt = "*-*-* 03:45:00";
      databases = [ "nextcloud" ];
    };

    services.borgbackup.jobs.nextcloud = {
      user = "root";
      group = "root";
      repo = "ssh://backup:23/./cloud";
      paths = [ "/var/lib/nextcloud" "/var/backup/postgresql/nextcloud.sql.gz" ];
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
