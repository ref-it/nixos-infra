{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.nextcloud-calendar;
in
{
  options.profiles.nextcloud-calendar = {
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

    services.nginx.virtualHosts."${cfg.fqdn}" = {};

    services.nextcloud = {
      enable = true;
      package = pkgs.nextcloud33;
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
          auto_provision = true;
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
        inherit calendar groupfolders notify_push richdocuments user_oidc;
      };
    };
  };
}
