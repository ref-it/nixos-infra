{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.keycloak;
in
{
  options.profiles.keycloak = {
    enable = mkEnableOption (mdDoc "Enable the Keycloak profile");
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    sops.secrets = {
      "keycloak-init-pw" = {
        owner = "keycloak";
        group = "keycloak";
        mode = "0400";
      };
    };

    services.keycloak = {
      enable = true;
      database = {
        passwordFile = config.sops.secrets."keycloak-init-pw".path;
      };
      settings = {
        hostname = "auth.stura-ilmenau.de";
        proxy = "edge";
      };
    };
  };
}
