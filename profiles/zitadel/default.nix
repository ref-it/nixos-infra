{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.zitadel;
in
{
  options.profiles.zitadel = {
    enable = mkEnableOption (mdDoc "Enable the Zitadel profile");

    fqdn = mkOption {
      type = types.str;
      description = mdDoc ''
        The FQDN for the nginx vHost of the Zitadel.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    sops.secrets = {
      "zitadel-master-key" = {
        owner = "zitadel";
        group = "zitadel";
        mode = "0400";
      };
      "zitadel-db-pass" = {
        owner = "postgres";
        group = "postgres";
        mode = "0400";
      };
      "zitadel-env" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    services.zitadel = {
      enable = true;
      masterKeyFile = config.sops.secrets."zitadel-master-key".path;
      settings = {
        Database.postgres = {
          Host = "localhost";
          Port = 5432;
          Database = "zitadel";
          User = {
            Username = "zitadel";
            SSL.Mode = "disable";
          };
          Admin = {
            Username = "zitadel";
            SSL.Mode = "disable";
          };
        };
        Machine.Identification = {
          PrivateIp.Enabled = false;
          Webhook.Enabled = false;
          Hostname.Enabled = true;
        };
        TLS.Enabled = false;
        ExternalPort = 443;
        ExternalDomain = cfg.fqdn;
      };
    };

    systemd.services.zitadel.serviceConfig.EnvironmentFile = config.sops.secrets."zitadel-env".path;

    services.nginx = {
      enable = true;
      virtualHosts."${cfg.fqdn}" = {
        forceSSL = true;
        enableACME = true;
        locations = {
          "/" = {
            proxyPass = "http://localhost:8080";
          };
        };
      };
    };

    services.postgresql = {
      enable = true;
      enableTCPIP = true;
      ensureUsers = [
        {
          name = "zitadel";
          ensurePermissions = {
            "DATABASE zitadel" = "ALL PRIVILEGES";
          };
          ensureClauses = {
            createdb = true;
            createrole = true;
          };
        }
      ];
      ensureDatabases = [
        "zitadel"
      ];
    };

    systemd.services.postgres-pw-setup = {
      description = "Password setup for postgresql";
      after = [ "postgresql.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.postgresql ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "postgres";
        Group = "postgres";
      };
      script = ''
        set -euo pipefail
        DB_PASSWORD=$(cat ${config.sops.secrets."zitadel-db-pass".path} | tr -d '\n')
        echo "ALTER USER zitadel WITH PASSWORD '$DB_PASSWORD';" | psql
      '';
    };
  };
}