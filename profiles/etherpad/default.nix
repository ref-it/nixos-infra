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
        WorkingDirectory = "/var/etherpad";
        ExecStart = "pnpm run prod";
        Restart = "always";
      };
      wantedBy = [ "default.target" ];
      after = [ "mysql.service" ]
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

    environment.systemPackages = [
      pkgs.etherpad-lite
    ];
  };
}