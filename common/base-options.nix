{ config, lib, pkgs, ... }:

with lib;

{
  options.base = {
    primaryIP = mkOption {
      type = types.str;
      description = mdDoc ''
        Primary IP used for deployment of this host.
      '';
    };
  };
}
