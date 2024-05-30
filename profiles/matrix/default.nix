{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.matrix;
in
{
  options.profiles.matrix = {
    enable = mkEnableOption "matrix server";

    fqdn = mkOption {
      type = types.str;
      description = "FQDN of the Matrix-Server";
    };
  };

  config = mkIf cfg.enable {
    sops.secrets = {
      "synapse-secret-config" = {
        owner = "matrix-synapse";
        group = "matrix-synapse";
        mode = "0400";

        restartUnits = [ "matrix-synapse.service" ];
      };
    };

    networking.firewall.extraInputRules = ''
      ip saddr 10.170.20.0/24 tcp dport 8008 accept
    '';

    environment.systemPackages = [ pkgs.matrix-synapse ];

    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_16;
      initdbArgs = [
        "--locale=C"
        "--encoding=UTF8"
      ];
      ensureDatabases = [ "matrix-synapse" ];
      ensureUsers = [
        {
          name = "matrix-synapse";
          ensureDBOwnership = true;
        }
      ];
    };

    services.matrix-synapse = {
      enable = true;
      withJemalloc = true;
      extraConfigFiles = [
        config.sops.secrets."synapse-secret-config".path
      ];
      settings = {
        server_name = cfg.fqdn;
        enable_registration = true;
        allowed_local_3pids = [
          {
            medium = "email";
            pattern = "^[^@]+@tu-ilmenau\.de$";
          }
        ];
        registrations_require_3pid = [ "email" ];
        database.name = "psycopg2";
        max_upload_size = "100M";
        listeners = [
          { port = 8008;
            bind_addresses = [ "0.0.0.0" ];
            type = "http";
            tls = false;
            x_forwarded = true;
            resources = [ {
              names = [ "client" "federation" ];
              compress = true;
            } ];
          }
        ];
      };
    };
  };
}
