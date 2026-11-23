{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.collabora;

  port = 9980;
  upstream = "http://[::1]:${toString port}";

  # Official Collabora CODE image, pinned by digest so the running version is
  # always what's committed here. To update:
  #   nix run nixpkgs#nix-prefetch-docker -- --image-name collabora/code \
  #     --image-tag <tag> --arch amd64 --os linux
  # and copy the tag, imageDigest and hash below.
  # Tags: https://hub.docker.com/r/collabora/code/tags
  imageName = "collabora/code";
  imageTag = "26.04.6.2.1";
  image = pkgs.dockerTools.pullImage {
    inherit imageName;
    imageDigest = "sha256:a2f5d4e88addd46033d8440f7a13b82f7e6fe444bf8c6b5a3eadc789f0b5342b";
    hash = "sha256-wVXvl2cR+RjBHcYSWG8BlvCcLYbzoy0Vi5CTv0dsrZU=";
    finalImageName = imageName;
    finalImageTag = imageTag;
  };

  # WOPI hosts allowed to open documents, one alias group per host.
  hostUrl = h: if hasInfix ":" h then "https://[${h}]:443" else "https://${h}:443";
  aliasGroups = listToAttrs (imap1 (i: h: nameValuePair "aliasgroup${toString i}" (hostUrl h)) cfg.trustedHosts);

  proxy = extra: {
    proxyPass = upstream;
    extraConfig = ''
      proxy_set_header Host $host;
    '' + extra;
  };
  wsProxy = proxy ''
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "Upgrade";
    proxy_read_timeout 36000s;
  '';
in
{
  options.profiles.collabora = {
    enable = mkEnableOption (mdDoc "Enable the Collabora profile");

    fqdn = mkOption {
      type = types.str;
      description = mdDoc ''
        The FQDN for the nginx vHost of Collabora.
      '';
    };

    trustedHosts = mkOption {
      type = types.listOf types.str;
      default = [];
      description = mdDoc ''
        List of hosts allowed to access Collabora Online.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    virtualisation.oci-containers.containers.collabora = {
      image = "${imageName}:${imageTag}";
      imageFile = image;
      environment = aliasGroups // {
        server_name = cfg.fqdn;
        DONT_GEN_SSL_CERT = "1";
        extra_params = concatStringsSep " " [
          "--o:ssl.enable=false"
          "--o:ssl.termination=true"
          # Host network (below): only reachable through nginx on this host.
          "--o:net.listen=loopback"
          "--o:remote_font_config.url=https://cloud.stura-ilmenau.de/apps/richdocuments/settings/fonts.json"
        ];
      };
      # Needed by coolwsd to set up its document jails.
      # Host network so WOPI requests to Nextcloud come from the host's own
      # address, which is what richdocuments' wopi_allowlist contains. On the
      # podman bridge they'd come from 10.88.0.x and get a 403.
      extraOptions = [
        "--cap-add=MKNOD"
        "--network=host"
        # The image's probe ignores extra_params and checks
        # https://127.0.0.1:9980, but we serve plain HTTP on [::1] only.
        ''--health-cmd=["/usr/bin/coolwsd","--probe","--o:ssl.enable=false","--o:net.proto=IPv6"]''
      ];
    };

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts."${cfg.fqdn}" = {
        forceSSL = true;
        enableACME = true;
        locations = {
          "^~ /browser" = proxy "" // { priority = 10; };
          "^~ /hosting/discovery" = proxy "" // { priority = 20; };
          "^~ /hosting/capabilities" = proxy "" // { priority = 30; };
          "~ ^/cool/(.*)/ws$" = wsProxy // { priority = 40; };
          "~ ^/(c|l)ool" = proxy "" // { priority = 50; };
          "^~ /cool/adminws" = wsProxy // { priority = 60; };
        };
      };
    };
  };
}
