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

    services.opencloud = {
      enable = true;
      url = cfg.fqdn;
    };
  };
}
