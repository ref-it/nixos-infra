{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  config = {
    system.stateVersion = "23.05";

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking.hostName = "luchs";

    base.primaryIP = "141.24.44.177";

    systemd.network = {
      enable = true;
      networks = {
        "40-enp2s0" = {
          name = "enp2s0";
          networkConfig = {
            IPv6AcceptRA = false;
          };
          address = [
            "141.24.44.177/25"
          ];
          gateway = [
            "141.24.44.255"
          ];
        };
      };
    };

    sops.defaultSopsFile = ./secrets.yaml;
    
    profiles.desktop-plasma6 = {
      enable = true;
    };

    users.users.guest = {
      isNormalUser = true;
      home = "/home/guest";
    };
  };
}
