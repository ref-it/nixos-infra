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

    sops.secrets = lib.genAttrs
      [ "nc-init-pw" ]
      (_: {
        owner = "nextcloud";
        group = "nextcloud";
        mode = "0400";
      });

    services.nextcloud = {
      enable = true;
      package = pkgs.nextcloud27;
      https = true;
      hostName = cfg.fqdn;
      autoUpdateApps.enable = true;
      configureRedis = true;
      maxUploadSize = "2048M";
      phpOptions = {
        "opcache.interned_strings_buffer" = "64";
        "opcache.memory_consumption" = "1024";
      };
      config = {
        extraTrustedDomains = cfg.extraDomains;
        trustedProxies = cfg.trustedProxies;
        dbtype = "mysql";
        dbname = "nextcloud";
        dbuser = "nextcloud";
        adminuser = "admin";
        adminpassFile = config.sops.secrets."nc-init-pw".path;
        dbhost = "localhost:/run/mysqld/mysqld.sock";
      };
    };
  };
}