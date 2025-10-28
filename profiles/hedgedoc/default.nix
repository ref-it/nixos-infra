{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.hedgedoc;
in
{
  options.profiles.hedgedoc = {
    enable = mkEnableOption (mdDoc "Enable the Hedgedoc profile");

    fqdn = mkOption {
      type = types.str;
      description = mdDoc ''
        The FQDN for the nginx vHost of Hedgedoc.
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
      "tls-cert" = {
        owner = "nginx";
        group = "nginx";
        mode = "0400";
      };
      "tls-cert-key" = {
        owner = "nginx";
        group = "nginx";
        mode = "0400";
      };
    };

    services = {
      postgresql = {
        enable = true;
        ensureDatabases = [ "hedgedoc" ];
        ensureUsers = [
          {
            name = "hedgedoc";
            ensureDBOwnership = true;
          }
        ];
      };

      hedgedoc = {
        enable = true;
        package = pkgs.hedgedoc;
        settings = {
          domain = "${cfg.fqdn}";
          protocolUseSSL = true;
          db = {
            username = "hedgedoc";
            database = "hedgedoc";
            host = "/run/postgresql";
            dialect = "postgresql";
          };
          allowOrigin = [
            "${cfg.fqdn}"
          ];
        };
        environmentFile = "/var/lib/hedgedoc/hedgedoc.env";
      };

      nginx = {
        enable = true;
        virtualHosts."${cfg.fqdn}" = {
          forceSSL = true;
          sslCertificate = config.sops.secrets."tls-cert".path;
          sslCertificateKey = config.sops.secrets."tls-cert-key".path;
          locations."/" = {
            proxyPass = "http://localhost:3000";
            extraConfig = ''
              proxy_set_header Host $host; 
              proxy_set_header X-Real-IP $remote_addr; 
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; 
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_headers_hash_bucket_size 128;
              allow 10.170.20.105;
              deny all;
            '';
          };
          locations."/socket.io/" = {
            proxyPass = "http://localhost:3000/socket.io/";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host $host; 
              proxy_set_header X-Real-IP $remote_addr; 
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; 
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_ssl_verify off;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "Upgrade";
              proxy_headers_hash_bucket_size 128;
              allow 10.170.20.105;
              deny all;
            '';
          };
        };
      };
      
      borgbackup.jobs.hedgedoc = {
        user = "root";
        group = "root";
        repo = "ssh://backup:23/./hedgedoc";
        readWritePaths = [ "/var/lib/hedgedoc/db-backup" ];
        preHook = ''
          cd /var/lib/hedgedoc
          rm -f db-backup/*
          ${pkgs.postgresql}/bin/pg_dump hedgedoc > db-backup/hedgedoc.sql
        '';
        paths = [ "uploads" "db-backup" ];
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
  };
}