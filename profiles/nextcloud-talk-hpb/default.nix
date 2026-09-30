{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.nextcloud-talk-hpb;

  # Janus lädt alle Module aus dem plugins-/transports-Ordner, daher nur die
  # benötigten (VideoRoom, WebSocket) verlinken.
  janusModules = pkgs.runCommand "janus-modules" { } ''
    mkdir -p $out/plugins $out/transports
    ln -s ${pkgs.janus-gateway}/lib/janus/plugins/libjanus_videoroom.so $out/plugins/
    ln -s ${pkgs.janus-gateway}/lib/janus/transports/libjanus_websockets.so $out/transports/
  '';

  janusConfDir = pkgs.linkFarm "janus-config" {
    "janus.jcfg" = pkgs.writeText "janus.jcfg" ''
      general: {
        configs_folder = "/etc/janus"
        plugins_folder = "${janusModules}/plugins"
        transports_folder = "${janusModules}/transports"
        events_folder = "/var/empty"
        loggers_folder = "/var/empty"
        debug_level = 4
      }
      media: {
        rtp_port_range = "${toString cfg.janusRtpPortRange.from}-${toString cfg.janusRtpPortRange.to}"
      }
      nat: {
        stun_server = "${cfg.turnFqdn}"
        stun_port = 3478
      }
    '';
    "janus.transport.websockets.jcfg" = pkgs.writeText "janus.transport.websockets.jcfg" ''
      general: {
        ws = true
        ws_ip = "127.0.0.1"
        ws_port = 8188
        wss = false
      }
    '';
    "janus.plugin.videoroom.jcfg" = pkgs.writeText "janus.plugin.videoroom.jcfg" ''
      general: {
      }
    '';
  };
in
{
  options.profiles.nextcloud-talk-hpb = {
    enable = mkEnableOption (mdDoc "Enable the Nextcloud Talk HPB profile");

    fqdn = mkOption {
      type = types.str;
      description = mdDoc ''
        The FQDN under which the signaling server is reachable
        (nginx location /standalone-signaling/).
      '';
    };

    nextcloudUrl = mkOption {
      type = types.str;
      example = "https://cloud.example.org";
      description = mdDoc "URL of the Nextcloud instance allowed to use this backend.";
    };

    janusRtpPortRange = {
      from = mkOption { type = types.port; default = 10000; };
      to = mkOption { type = types.port; default = 20000; };
    };

    turnFqdn = mkOption {
      type = types.str;
      description = mdDoc "The FQDN of the coturn TURN server.";
    };
  };

  config = mkIf cfg.enable {
    sops.secrets = {
      # Alle Dateien enthalten nur den jeweiligen Wert (kein KV-Format)
      "signaling-hashkey" = { owner = "nextcloud-spreed-signaling"; mode = "0400"; };
      "signaling-blockkey" = { owner = "nextcloud-spreed-signaling"; mode = "0400"; };
      "signaling-internalsecret" = { owner = "nextcloud-spreed-signaling"; mode = "0400"; };
      "signaling-backend-secret" = { owner = "nextcloud-spreed-signaling"; mode = "0400"; };
      "signaling-turn-apikey" = { owner = "nextcloud-spreed-signaling"; mode = "0400"; };
      "coturn-static-auth-secret" = { owner = "turnserver"; mode = "0400"; };
      # gleicher Wert, lesbar für den Signaling-Server
      "signaling-turn-secret" = {
        key = "coturn-static-auth-secret";
        owner = "nextcloud-spreed-signaling";
        mode = "0400";
      };
    };

    services.nats.enable = true;

    # Janus: kein NixOS-Modul vorhanden, daher eigener systemd-Service
    users.users.janus = { isSystemUser = true; group = "janus"; };
    users.groups.janus = { };
    environment.etc."janus".source = janusConfDir;

    systemd.services.janus = {
      description = "Janus WebRTC Server";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ janusConfDir ];
      serviceConfig = {
        ExecStart = "${pkgs.janus-gateway}/bin/janus --config=/etc/janus/janus.jcfg --configs-folder=/etc/janus";
        User = "janus";
        Group = "janus";
        Restart = "on-failure";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };

    services.nextcloud-spreed-signaling = {
      enable = true;
      backends.nextcloud = {
        urls = [ cfg.nextcloudUrl ];
        secretFile = config.sops.secrets."signaling-backend-secret".path;
      };
      settings = {
        http.listen = "127.0.0.1:8080";
        nats.url = [ "nats://localhost:4222" ];
        mcu = {
          type = "janus";
          url = "ws://127.0.0.1:8188";
        };
        turn = {
          servers = [
            "turn:${cfg.turnFqdn}:3478?transport=udp"
            "turn:${cfg.turnFqdn}:3478?transport=tcp"
          ];
          apikeyFile = config.sops.secrets."signaling-turn-apikey".path;
          secretFile = config.sops.secrets."signaling-turn-secret".path;
        };
        sessions = {
          hashkeyFile = config.sops.secrets."signaling-hashkey".path;
          blockkeyFile = config.sops.secrets."signaling-blockkey".path;
        };
        clients.internalsecretFile = config.sops.secrets."signaling-internalsecret".path;
      };
    };
    systemd.services.nextcloud-spreed-signaling = {
      after = [ "janus.service" "nats.service" ];
      wants = [ "janus.service" "nats.service" ];
    };

    # coturn
    services.coturn = {
      enable = true;
      use-auth-secret = true;
      static-auth-secret-file = config.sops.secrets."coturn-static-auth-secret".path;
      realm = cfg.turnFqdn;
      min-port = 49152;
      max-port = 65535;
      # TLS (turns:) auf 5349 mit dem ACME-Zertifikat von turnFqdn
      cert = "/var/lib/acme/${cfg.turnFqdn}/fullchain.pem";
      pkey = "/var/lib/acme/${cfg.turnFqdn}/key.pem";
    };

    # Zertifikat über den nginx-vHost beziehen (HTTP-01); coturn liest es
    # über die nginx-Gruppe und wird bei Erneuerung neu geladen.
    # (+ nginx: Signaling-Endpunkt unter dem Nextcloud-vHost)
    services.nginx.virtualHosts = mkMerge [
      { "${cfg.turnFqdn}".enableACME = true; }
      {
        "${cfg.fqdn}".locations."/standalone-signaling/" = {
          proxyPass = "http://127.0.0.1:8080/";
          proxyWebsockets = true;
          recommendedProxySettings = true;
        };
      }
    ];
    security.acme.certs."${cfg.turnFqdn}".reloadServices = [ "coturn.service" ];
    users.users.turnserver.extraGroups = [ "nginx" ];

    networking.firewall = {
      allowedTCPPorts = [ 3478 5349 ];
      allowedUDPPorts = [ 3478 5349 ];
      allowedUDPPortRanges = [
        { from = 49152; to = 65535; }
        { inherit (cfg.janusRtpPortRange) from to; }
      ];
    };
  };
}