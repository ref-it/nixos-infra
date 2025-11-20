{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.opencloud-kiste;
in
{
  options.profiles.opencloud-kiste = {
    enable = mkEnableOption (mdDoc "Enable the OpenCloud (Kiste) profile");

    fqdn = mkOption {
      type = types.str;
      description = mdDoc ''
        The FQDN for the nginx vHost of the OpenCloud (Kiste).
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

    services.opencloud = {
      enable = true;
      url = cfg.fqdn;
    };

    services.nginx = {
      enable = true;
      virtualHosts."${cfg.fqdn}" = {
        forceSSL = true;
        sslCertificate = config.sops.secrets."tls-cert".path;
        sslCertificateKey = config.sops.secrets."tls-cert-key".path;
        locations."/" = {
          proxyPass = "http://${config.services.opencloud.address}:${config.services.opencloud.port}";
          recommendedProxySettings = true;
        };
      };
    };
  };
}
