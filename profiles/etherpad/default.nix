{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.etherpad;
in
{
  options.profiles.etherpad = {
    enable = mkEnableOption (mdDoc "Enable the Etherpad profile");

    fqdn = mkOption {
      type = types.str;
      description = mdDoc ''
        The FQDN for the nginx vHost of Etherpad.
      '';
    };

    aliasDomains = mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        List of alternative Domains for the nginx vHost of Etherpad.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    sops.secrets = {
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

    systemd.services.etherpad = {
      enable = true;
      description = "Etherpad Lite, the collaborative editor.";
      serviceConfig = {
        Type = "simple";
        WorkingDirectory = "/var/lib/etherpad-lite";
        ExecStart = "${pkgs.pnpm}/bin/pnpm run prod";
        Restart = "always";
        User = "etherpad";
        Group = "etherpad";
        Environment = [
          "NODE_ENV=production"
          "PATH=${pkgs.nodejs_24}/bin:${pkgs.pnpm}/bin:/run/current-system/sw/bin"
        ];
      };
      after = [ "syslog.target" "network.target" ];
      wantedBy = [ "multi-user.target" ];
    };

    services = {
      nginx = {
        enable = true;
        virtualHosts."${cfg.fqdn}" = {
          serverAliases = cfg.aliasDomains;
          forceSSL = true;
          sslCertificate = config.sops.secrets."tls-cert".path;
          sslCertificateKey = config.sops.secrets."tls-cert-key".path;
          locations."/" = {
            proxyPass = "http://localhost:9001";
            extraConfig = ''
              allow 10.170.20.105;
              deny all;
            '';
          };
        };
      };
    };

    users.users.etherpad = {
      isNormalUser = true;
      home = "/var/lib/etherpad-lite";
    };

    users.groups.etherpad.members = [ "etherpad" ];

    environment.systemPackages = [
      pkgs.git
      pkgs.nodejs_24
      pkgs.pnpm
    ];
  };
}