{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.nextcloud-kiste;
in
{
  options.profiles.nextcloud-kiste = {
    enable = mkEnableOption (mdDoc "Enable the Nextcloud (Kiste) profile");

    name = mkOption {
      type = types.str;
      description = mdDoc ''
        The name of the Nextcloud.
      '';
    };

    fqdn = mkOption {
      type = types.str;
      description = mdDoc ''
        The FQDN for the nginx vHost of the Nextcloud (Kiste).
      '';
    };

    dir = mkOption {
      type = types.str;
      description = mdDoc ''
        Directory of the Nextcloud.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    services = {
      postgresql = {
        enable = true;
        ensureDatabases = [ "${cfg.name}" ];
        authentication = pkgs.lib.mkOverride 10 ''
          #type database  DBuser  auth-method
          local sameuser  all     trust
        '';
      };

      phpfpm.pools.${cfg.name} = {
        user = cfg.name;
        settings = {
          "listen.owner" = config.services.nginx.user;
          "pm" = "dynamic";
          "pm.max_children" = 32;
          "pm.max_requests" = 500;
          "pm.start_servers" = 2;
          "pm.min_spare_servers" = 2;
          "pm.max_spare_servers" = 5;
          "php_admin_value[error_log]" = "stderr";
          "php_admin_flag[log_errors]" = true;
          "catch_workers_output" = true;
        };
        phpOptions = ''
          extension=${pkgs.phpExtensions.redis}/lib/php/extensions/redis.so
          extension=${pkgs.phpExtensions.apcu}/lib/php/extensions/apcu.so
        '';
        phpEnv."PATH" = lib.makeBinPath [ pkgs.php ];
      };

      nginx = {
        enable = true;
        virtualHosts = {
          ${cfg.fqdn} = {
            forceSSL = true;
            enableACME = true;
            locations."/" = {
              root = cfg.dir;
              extraConfig = ''
                fastcgi_split_path_info ^(.+\.php)(/.+)$;
                fastcgi_pass unix:${config.services.phpfpm.pools.${cfg.name}.socket};
                include ${pkgs.nginx}/conf/fastcgi.conf;
              '';
            };
          };
        };
      };
    };

    sops.secrets = {
      "borg-passphrase" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    users = {
      users.${cfg.name} = {
        isSystemUser = true;
        createHome = true;
        home = cfg.dir;
        group = cfg.name;
      };
      groups.${cfg.name} = {};
    };
  };
}
