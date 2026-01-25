{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.zammad;
in
{
  options.profiles.zammad = {
    enable = mkEnableOption (mdDoc "Enable the Zammad profile");

    bindHost = mkOption {
      type = types.str;
      description = mdDoc ''
        The FQDN for the nginx vHost of the Zammad.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.extraInputRules = ''
      ip saddr 10.170.20.0/24 tcp dport 3000 accept comment "zammad"
      ip saddr 10.170.20.0/24 tcp dport 6042 accept comment "zammad"
      ip6 saddr 2001:638:904:ffd0::/64 tcp dport 3000 accept comment "zammad"
      ip6 saddr 2001:638:904:ffd0::/64 tcp dport 6042 accept comment "zammad"
    '';

    sops.secrets = {
      "zammad-secret-key" = {
        owner = "zammad";
        group = "zammad";
        mode = "0400";
      };
      "borg-passphrase" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    systemd.services = {
      "zammad-conf-ticket-default-type" = {
        wantedBy = [ "zammad-web.service" ];
        after = [ "zammad-web.service" ];
        environment = {
          RAILS_ENV = "production";
          RAILS_LOG_TO_STDOUT = "true";
        };
        serviceConfig = {
          Type = "oneshot";
          WorkingDirectory = "${pkgs.zammad}";
          ExecStart = ''${pkgs.zammad}/bin/rails r "Setting.set('ui_ticket_create_default_type', 'email-out')"'';
          Group = "zammad";
          User = "zammad";
        };
      };
      "zammad-conf-select-customer-with-email" = {
        wantedBy = [ "zammad-web.service" ];
        after = [ "zammad-web.service" ];
        environment = {
          RAILS_ENV = "production";
          RAILS_LOG_TO_STDOUT = "true";
        };
        serviceConfig = {
          Type = "oneshot";
          WorkingDirectory = "${pkgs.zammad}";
          ExecStart = ''${pkgs.zammad}/bin/rails r "Setting.set('ui_user_organization_selector_with_email', true)"'';
          Group = "zammad";
          User = "zammad";
        };
      };
    };

    services.zammad = {
      enable = true;
      host = cfg.bindHost;
      secretKeyBaseFile = config.sops.secrets."zammad-secret-key".path;
    };

    services.postgresqlBackup = {
      enable = true;
      startAt = "*-*-* 03:10:00";
      databases = [ "zammad" ];
    };

    services.borgbackup.jobs.zammad = {
      user = "root";
      group = "root";
      repo = "ssh://backup:23/./zammad";
      paths = [ "/var/lib/zammad" "/var/backup/postgresql/zammad.sql.gz" ];
      doInit = false;
      startAt = [ "*-*-* 03:40:00" ];
      encryption.mode = "repokey";
      encryption.passCommand = "cat ${config.sops.secrets."borg-passphrase".path}";
      prune.keep.within = "1y";
      compression = "auto,zstd";
      dateFormat = "+%Y-%m-%d";
      archiveBaseName = "backup";
    };
  };
}