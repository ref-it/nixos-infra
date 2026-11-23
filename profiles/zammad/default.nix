{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.zammad;

  # elasticsearch
  ociImages = import ../../oci-images { inherit lib pkgs; };
  esPort = 9200;
  esDataDir = "/var/lib/zammad-search";
  esUid = 920;
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

    elasticsearch = {
      enable = mkEnableOption (mdDoc "an Elasticsearch container as Zammad's search index");

      heapSize = mkOption {
        type = types.str;
        default = "1g";
        description = mdDoc "JVM heap size of Elasticsearch (-Xms/-Xmx).";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [ {
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
      "zammad-conf-table-group-by-show-count" = {
        wantedBy = [ "zammad-web.service" ];
        after = [ "zammad-web.service" ];
        environment = {
          RAILS_ENV = "production";
          RAILS_LOG_TO_STDOUT = "true";
        };
        serviceConfig = {
          Type = "oneshot";
          WorkingDirectory = "${pkgs.zammad}";
          ExecStart = ''${pkgs.zammad}/bin/rails r "Setting.set('ui_table_group_by_show_count', true)"'';
          Group = "zammad";
          User = "zammad";
        };
      };
      "zammad-conf-make-marc-admin" = {
        wantedBy = [ "zammad-web.service" ];
        after = [ "zammad-web.service" ];
        environment = {
          RAILS_ENV = "production";
          RAILS_LOG_TO_STDOUT = "true";
        };
        serviceConfig = {
          Type = "oneshot";
          WorkingDirectory = "${pkgs.zammad}";
          ExecStart = ''${pkgs.zammad}/bin/rails r "User.find_by(email: 'marc.schlagenhauf@tu-ilmenau.de').roles = Role.where(name: ['Admin', 'Agent'])"'';
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
  }

  (mkIf cfg.elasticsearch.enable {
    # Required by Elasticsearch, can't be set from inside the container.
    boot.kernel.sysctl."vm.max_map_count" = 262144;

    users.users.zammad-elasticsearch = {
      isSystemUser = true;
      uid = esUid;
      group = "zammad-elasticsearch";
    };
    users.groups.zammad-elasticsearch.gid = esUid;

    # Index data only, not backed up: it can be rebuilt from the database.
    # Group 0 because the image requires GID 0 when running as another uid.
    systemd.tmpfiles.rules = [ "d ${esDataDir} 0750 ${toString esUid} 0 -" ];

    virtualisation.oci-containers.containers.zammad-elasticsearch = {
      inherit (ociImages.elasticsearch) image imageFile;
      user = "${toString esUid}:0";
      volumes = [ "${esDataDir}:/usr/share/elasticsearch/data" ];
      environment = {
        "discovery.type" = "single-node";
        "network.host" = "127.0.0.1";
        "http.port" = toString esPort;
        "xpack.security.enabled" = "false";
        "action.auto_create_index" = "false";
        ES_JAVA_OPTS = "-Xms${cfg.elasticsearch.heapSize} -Xmx${cfg.elasticsearch.heapSize}";
      };
      extraOptions = [ "--network=host" ];
    };

    systemd.services."zammad-searchindex-rebuild" = {
      requires = [ "podman-zammad-elasticsearch.service" ];
      after = [ "podman-zammad-elasticsearch.service" "zammad-conf-es-url.service" ];
      environment = {
        RAILS_ENV = "production";
        RAILS_LOG_TO_STDOUT = "true";
      };
      serviceConfig = {
        Type = "oneshot";
        WorkingDirectory = "${pkgs.zammad}";
        # The container unit is "started" long before Elasticsearch answers
        # (~90 s on miraculix), so wait for it.
        ExecStartPre = pkgs.writeShellScript "wait-for-elasticsearch" ''
          for _ in $(seq 1 60); do
            ${pkgs.curl}/bin/curl -sf -m 3 http://127.0.0.1:${toString esPort} >/dev/null && exit 0
            sleep 5
          done
          echo "Elasticsearch not reachable after 5 minutes" >&2
          exit 1
        '';
        ExecStart = "${pkgs.zammad}/bin/rake zammad:searchindex:rebuild";
        Group = "zammad";
        User = "zammad";
      };
    };

    systemd.services."zammad-conf-es-url" = {
      wantedBy = [ "zammad-web.service" ];
      after = [ "zammad-web.service" ];
      environment = {
        RAILS_ENV = "production";
        RAILS_LOG_TO_STDOUT = "true";
      };
      serviceConfig = {
        Type = "oneshot";
        WorkingDirectory = "${pkgs.zammad}";
        ExecStart = ''${pkgs.zammad}/bin/rails r "Setting.set('es_url', 'http://127.0.0.1:${toString esPort}')"'';
        Group = "zammad";
        User = "zammad";
      };
    };
  })
  ]);
}