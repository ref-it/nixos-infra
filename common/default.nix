{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    inputs.sops.nixosModules.sops

    ./base-options.nix
    ./users.nix

    ../profiles
  ];

  config = {
    boot.tmp.useTmpfs = true;
    networking.nftables.enable = true;
    networking.firewall.enable = true;
    networking.firewall.allowPing = true;
    networking.firewall.rejectPackets = true;

    networking.useDHCP = false;
    networking.dhcpcd.enable = false;

    deployment.targetUser = null;
    deployment.targetHost = config.base.primaryIP;

    networking.domain = "infra.stura-ilmenau.de";

    networking.nameservers = [
      "2001:638:904:ffcc::3"
      "2001:638:904:ffcc::4"
    ];

    time.timeZone = "Europe/Berlin";

    i18n.defaultLocale = "en_US.UTF-8";
    console = {
      font = "Lat2-Terminus16";
      keyMap = "de-latin1";
    };

    security.sudo.wheelNeedsPassword = false;

    environment.systemPackages = with pkgs; [
      htop
      tmux
      wget
      vim
      screen
    ];

    programs.mtr.enable = true;

    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = lib.mkDefault "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };

    nix.settings = {
      trusted-users = [ "@wheel" ];
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
    };
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
    nix.extraOptions = ''
      min-free = ${toString (100 * 1024 * 1024)}
      max-free = ${toString (1024 * 1024 * 1024)}
    '';

    # Pin current nixpkgs channel and flake registry to the nixpkgs version
    # the host got build with
    nix.nixPath = lib.mkForce [ "nixpkgs=${lib.cleanSource pkgs.path}" ];
    nix.registry = lib.mkForce {
      "nixpkgs" = {
        from = {
          type = "indirect";
          id = "nixpkgs";
        };
        to = {
          type = "path";
          path = lib.cleanSource pkgs.path;
        };
        exact = true;
      };
    };

    services.nginx = {
      enableReload = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
    };

    security.acme = {
      acceptTerms = true;
      defaults.email = "ref-it@tu-ilmenau.de";
    };
  };
}